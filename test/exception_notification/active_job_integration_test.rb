# frozen_string_literal: true

require "test_helper"
require "active_job"
require "exception_notification"
require "exception_notification/once/campfire/active_job_integration"
require "exception_notification/once/campfire/sidekiq_integration"

class DiscardIntegrationTestJob < ActiveJob::Base
  include ExceptionNotification::Once::Campfire::ActiveJobIntegration
  discard_on RuntimeError

  def perform
    raise "boom"
  end
end

class UnhandledIntegrationTestJob < ActiveJob::Base
  include ExceptionNotification::Once::Campfire::ActiveJobIntegration

  def perform
    raise "boom"
  end
end

class SidekiqRetryExhaustionTestJob < ActiveJob::Base
  include ExceptionNotification::Once::Campfire::ActiveJobDiscardIntegration
  retry_on RuntimeError, attempts: 1

  def perform
    raise "boom"
  end
end

class FakeSidekiqConfig
  attr_reader :death_handlers

  def initialize
    @death_handlers = []
  end
end

class ActiveJobIntegrationTest < Minitest::Test
  def teardown
    ExceptionNotifier.unregister_exception_notifier(:capture)
  end

  def test_sidekiq_integration_notifies_when_an_active_job_is_discarded
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    job_class = Class.new(ActiveJob::Base) do
      include ExceptionNotification::Once::Campfire::ActiveJobDiscardIntegration
      discard_on RuntimeError

      def perform
        raise "boom"
      end
    end

    job_class.perform_now

    assert_equal 1, notifications.size
    assert_equal "discarded", notifications.first.last.dig(:data, :action)
  end

  def test_sidekiq_integration_leaves_exhausted_active_job_retries_to_sidekiq
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    assert_raises(RuntimeError) { SidekiqRetryExhaustionTestJob.perform_now }

    assert_empty notifications
  end

  def test_sidekiq_integration_registers_its_death_handler_once
    config = FakeSidekiqConfig.new

    with_sidekiq(config) do
      ActiveSupport.stub(:on_load, ->(*) { }) do
        ExceptionNotification::Once::Campfire::SidekiqIntegration.install!
        ExceptionNotification::Once::Campfire::SidekiqIntegration.install!
      end
    end

    assert_equal 1, config.death_handlers.size
  end

  def test_sidekiq_integration_reports_the_wrapped_active_job_class
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })
    config = FakeSidekiqConfig.new

    with_sidekiq(config) do
      ActiveSupport.stub(:on_load, ->(*) { }) do
        ExceptionNotification::Once::Campfire::SidekiqIntegration.install!
      end
    end

    config.death_handlers.fetch(0).call(
      { "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper", "wrapped" => "ExampleJob", "jid" => "123" },
      RuntimeError.new("boom")
    )

    assert_equal "ExampleJob", notifications.first.last.dig(:data, :job)
  end

  def test_active_job_integration_notifies_discarded_jobs_once
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    DiscardIntegrationTestJob.perform_now

    assert_equal 1, notifications.size
    assert_equal "discarded", notifications.first.last.dig(:data, :action)
  end

  def test_active_job_integration_covers_jobs_that_define_discard_callbacks_first
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    job_base = Class.new(ActiveJob::Base)
    job_class = Class.new(job_base) do
      after_discard { }
      discard_on RuntimeError

      def perform
        raise "boom"
      end
    end
    job_base.include(ExceptionNotification::Once::Campfire::ActiveJobIntegration)

    job_class.perform_now

    assert_equal 1, notifications.size
    assert_equal "discarded", notifications.first.last.dig(:data, :action)
  end

  def test_active_job_integration_notifies_unhandled_jobs_once
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    assert_raises(RuntimeError) { UnhandledIntegrationTestJob.perform_now }

    assert_equal 1, notifications.size
    assert_nil notifications.first.last.dig(:data, :action)
  end

  private

  def with_sidekiq(config)
    Object.const_set(:Sidekiq, Module.new)
    Sidekiq.define_singleton_method(:configure_server) { |&block| block.call(config) }
    yield
  ensure
    Object.send(:remove_const, :Sidekiq)
  end
end

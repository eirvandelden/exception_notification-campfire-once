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

  def test_active_job_integration_notifies_discarded_jobs_once
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    DiscardIntegrationTestJob.perform_now

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
end

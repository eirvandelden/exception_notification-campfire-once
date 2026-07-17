# frozen_string_literal: true

require "test_helper"
require "active_job"
require "exception_notification"
require "exception_notification/once/campfire/active_job_integration"
require "exception_notification/once/campfire/sidekiq_integration"

class DiscardIntegrationTestJob < ActiveJob::Base
  include ExceptionNotification::Once::Campfire::ActiveJobIntegration
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

  def test_active_job_integration_notifies_from_after_discard
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })

    DiscardIntegrationTestJob.new.send(:run_after_discard_procs, RuntimeError.new("boom"))

    assert_equal 1, notifications.size
    assert_equal "discarded", notifications.first.last.dig(:data, :action)
  end
end

# frozen_string_literal: true

require "test_helper"
require "active_job"
require "exception_notification"
require "exception_notification/once/campfire/sidekiq_integration"

class ActiveJobIntegrationTest < Minitest::Test
  def teardown
    ExceptionNotifier.unregister_exception_notifier(:capture)
  end

  def test_sidekiq_integration_notifies_when_an_active_job_is_discarded
    notifications = []
    ExceptionNotifier.register_exception_notifier(:capture, ->(exception, options) { notifications << [ exception, options ] })
    ActiveJob::Base.include(ExceptionNotification::Once::Campfire::ActiveJobDiscardIntegration)

    job_class = Class.new(ActiveJob::Base) do
      discard_on RuntimeError

      def perform
        raise "boom"
      end
    end

    job_class.perform_now

    assert_equal 1, notifications.size
    assert_equal "discarded", notifications.first.last.dig(:data, :action)
  end
end

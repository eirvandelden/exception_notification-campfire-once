# frozen_string_literal: true

require "active_support/concern"

module ExceptionNotification
  module Once
    module Campfire
      module SidekiqIntegration
        DEATH_HANDLER = ->(job, exception) do
          ExceptionNotifier.notify_exception(exception, data: { job: job["wrapped"] || job["class"], jid: job["jid"] })
        end

        def self.install!
          Sidekiq.configure_server do |config|
            config.death_handlers << DEATH_HANDLER unless config.death_handlers.include?(DEATH_HANDLER)
          end

          ActiveSupport.on_load(:active_job) do
            include ExceptionNotification::Once::Campfire::ActiveJobDiscardIntegration
          end
        end
      end

      module ActiveJobDiscardIntegration
        extend ActiveSupport::Concern

        def perform_now
          @exception_notification_discarded_exception = nil
          result = super

          if @exception_notification_discarded_exception
            ExceptionNotifier.notify_exception(
              @exception_notification_discarded_exception,
              data: { job: self.class.name, action: "discarded" }
            )
          end

          result
        ensure
          @exception_notification_discarded_exception = nil
        end

        def run_after_discard_procs(exception)
          @exception_notification_discarded_exception = exception
          super
        end
        private :run_after_discard_procs
      end
    end
  end
end

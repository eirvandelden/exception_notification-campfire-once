# frozen_string_literal: true

require "active_support/concern"

module ExceptionNotification
  module Once
    module Campfire
      module ActiveJobIntegration
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
        rescue => exception
          ExceptionNotifier.notify_exception(exception, data: { job: self.class.name })
          raise
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

# frozen_string_literal: true

require "active_support/concern"

module ExceptionNotification
  module Once
    module Campfire
      module ActiveJobIntegration
        extend ActiveSupport::Concern

        included do
          around_perform do |_job, block|
            block.call
          rescue => exception
            ExceptionNotifier.notify_exception(exception, data: { job: self.class.name })
            raise
          end

          def discard_job(exception)
            ExceptionNotifier.notify_exception(exception, data: { job: self.class.name, action: "discarded" })
          end
        end
      end
    end
  end
end

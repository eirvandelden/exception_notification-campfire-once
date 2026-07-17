# frozen_string_literal: true

require "active_support/concern"

module ExceptionNotification
  module Once
    module Campfire
      module SidekiqIntegration
        def self.install!
          Sidekiq.configure_server do |config|
            config.death_handlers << ->(job, exception) do
              ExceptionNotifier.notify_exception(exception, data: { job: job["class"], jid: job["jid"] })
            end
          end

          ActiveSupport.on_load(:active_job) do
            include ExceptionNotification::Once::Campfire::ActiveJobDiscardIntegration
          end
        end
      end

      module ActiveJobDiscardIntegration
        extend ActiveSupport::Concern

        included do
          def discard_job(exception)
            ExceptionNotifier.notify_exception(exception, data: { job: self.class.name, action: "discarded" })
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "exception_notification"
require "exception_notification/once/campfire/version"
require "exception_notifier/once/campfire_notifier"

module ExceptionNotification
  module Once
    module Campfire
      def self.install!(webhook_url:, app_name: nil, background: :active_job)
        unless %i[active_job sidekiq].include?(background)
          raise ArgumentError, "Unknown background: #{background.inspect}. Use :active_job or :sidekiq."
        end

        resolved_app_name = app_name || begin
          Rails.application.class.module_parent_name
        rescue StandardError
          "App"
        end

        Rails.application.config.middleware.use(
          ExceptionNotification::Rack,
          campfire: { webhook_url: webhook_url, app_name: resolved_app_name }
        )

        case background
        when :active_job
          require "exception_notification/once/campfire/active_job_integration"
          install_active_job_hooks!
        when :sidekiq
          require "exception_notification/once/campfire/sidekiq_integration"
          ExceptionNotification::Once::Campfire::SidekiqIntegration.install!
        end
      end

      def self.install_active_job_hooks!
        ActiveSupport.on_load(:active_job) do
          include ExceptionNotification::Once::Campfire::ActiveJobIntegration
        end
      end
      private_class_method :install_active_job_hooks!
    end
  end
end

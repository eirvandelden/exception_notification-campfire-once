# frozen_string_literal: true

require "net/http"
require "socket"
require "uri"
require "active_support/parameter_filter"

module ExceptionNotifier
  class CampfireNotifier < ExceptionNotifier::BaseNotifier
      def initialize(options)
        super
        @webhook_url = options.fetch(:webhook_url)
        @app_name = options[:app_name] || begin
          Rails.application.class.module_parent_name
        rescue StandardError
          "App"
        end
      end

      def call(exception, options = {})
        text = build_text(exception, options)
        begin
          uri = URI.parse(@webhook_url)
          send_notice(exception, options, text) do
            Net::HTTP.post(uri, text, "Content-Type" => "text/plain")
          end
        rescue StandardError => e
          Rails.logger.error("CampfireNotifier failed: #{e.class}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
        end
      end

      private

      def build_text(exception, options)
        env = options[:env]
        sections = []

        sections << "🚨 #{@app_name}: #{exception.class}: #{exception.message}"

        if env
          request = if defined?(ActionDispatch::Request)
            ActionDispatch::Request.new(env)
          else
            Rack::Request.new(env)
          end
          params = if request.respond_to?(:filtered_parameters)
            request.filtered_parameters
          else
            ActiveSupport::ParameterFilter.new(filter_parameters(env)).filter(request.params)
          end
          url = request.respond_to?(:filtered_path) ? "#{request.base_url}#{request.filtered_path}" : "#{request.base_url}#{request.path}"
          sections << "--- Request ---\nURL: #{url}\nMethod: #{request.request_method}\nParams: #{params.inspect}\nRemote IP: #{request.ip}\nUser-Agent: #{env['HTTP_USER_AGENT']}"
        end

        env_info = []
        env_info << "Rails Env: #{Rails.env}" rescue nil
        env_info << "Host: #{Socket.gethostname}" rescue nil
        env_info << "Time: #{Time.current}" rescue nil
        sections << "--- Environment ---\n#{env_info.compact.join("\n")}" unless env_info.compact.empty?

        backtrace = begin
          cleaned = Rails.backtrace_cleaner.clean(Array(exception.backtrace))
          cleaned.empty? ? Array(exception.backtrace) : cleaned
        rescue
          Array(exception.backtrace)
        end
        sections << "--- Backtrace ---\n#{backtrace.first(20).join("\n")}" unless backtrace.empty?

        sections.join("\n\n")
      end

      def filter_parameters(env)
        Array(env["action_dispatch.parameter_filter"]) + [ :password, :secret, :token ]
      end
  end
end

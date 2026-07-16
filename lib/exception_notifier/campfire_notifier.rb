# frozen_string_literal: true

require "net/http"
require "socket"
require "uri"

class ExceptionNotifier::CampfireNotifier < ExceptionNotifier::BaseNotifier
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
      Net::HTTP.post(uri, text, "Content-Type" => "text/plain")
    rescue StandardError => e
      Rails.logger.error("CampfireNotifier failed: #{e.class}: #{e.message}")
    end
  end

  private

  def build_text(exception, options)
    env = options[:env]
    sections = []

    # Header
    sections << "🚨 #{@app_name}: #{exception.class}: #{exception.message}"

    # Request section
    if env
      request = Rack::Request.new(env)
      sections << "--- Request ---\nURL: #{request.url}\nMethod: #{request.request_method}\nParams: #{request.params.inspect}\nRemote IP: #{request.ip}\nUser-Agent: #{env['HTTP_USER_AGENT']}"
    end

    # Session section
    if env && env["rack.session"] && !env["rack.session"].empty?
      sections << "--- Session ---\n#{env['rack.session'].to_h.inspect}"
    end

    # Environment section
    env_info = []
    env_info << "Rails Env: #{Rails.env}" rescue nil
    env_info << "Host: #{Socket.gethostname}" rescue nil
    env_info << "Time: #{Time.current}" rescue nil
    sections << "--- Environment ---\n#{env_info.compact.join("\n")}" unless env_info.compact.empty?

    # Backtrace section
    backtrace = begin
      cleaned = Rails.backtrace_cleaner.clean(Array(exception.backtrace))
      cleaned.empty? ? Array(exception.backtrace) : cleaned
    rescue
      Array(exception.backtrace)
    end
    sections << "--- Backtrace ---\n#{backtrace.first(20).join("\n")}" unless backtrace.empty?

    sections.join("\n\n")
  end
end

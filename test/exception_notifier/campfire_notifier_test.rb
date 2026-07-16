# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "logger"

# Stub ExceptionNotifier::BaseNotifier since exception_notification gem
# is not a test dependency.
module ExceptionNotifier
  class BaseNotifier
    def initialize(options = {}); end
  end
end

# Stub Rails to satisfy campfire_notifier.rb dependencies.
module Rails
  def self.logger
    @logger ||= Logger.new(nil)
  end

  def self.backtrace_cleaner
    @bc ||= Object.new.tap { |o| o.define_singleton_method(:clean) { |bt| bt } }
  end

  def self.env
    "test"
  end
end

require "exception_notifier/campfire_notifier"

class CampfireNotifierTest < Minitest::Test
  def setup
    @webhook_url = "https://example.com/rooms/1/abc123/messages"
    @notifier = ExceptionNotifier::CampfireNotifier.new(
      webhook_url: @webhook_url,
      app_name: "TestApp"
    )
    @exception = begin
      raise RuntimeError, "something went wrong"
    rescue => e
      e
    end
  end

  def test_posts_to_webhook_url
    captured_uri = nil
    Net::HTTP.stub(:post, ->(uri, _body, _headers) { captured_uri = uri; nil }) do
      @notifier.call(@exception)
    end
    assert_equal @webhook_url, captured_uri.to_s
  end

  def test_body_contains_exception_info
    captured_body = nil
    Net::HTTP.stub(:post, ->(_uri, body, _headers) { captured_body = body; nil }) do
      @notifier.call(@exception)
    end
    assert_includes captured_body, "RuntimeError"
    assert_includes captured_body, "something went wrong"
    assert_match(/campfire_notifier_test/, captured_body)
  end

  def test_swallows_http_errors
    Net::HTTP.stub(:post, ->(*) { raise StandardError, "network error" }) do
      assert_silent { @notifier.call(@exception) }
    end
  end
end

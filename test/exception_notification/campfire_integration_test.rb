# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "exception_notification"
require "exception_notification/once/campfire"

module Rails
  def self.application
    nil
  end
end

class FakeMiddlewareStack
  def initialize
    @entries = []
  end

  def use(klass, **options)
    @entries << klass.new(->(_env) { [ 200, {}, [] ] }, options)
  end

  def include?(klass)
    @entries.any? { |entry| entry.is_a?(klass) }
  end
end

class FakeRailsConfig
  attr_reader :middleware

  def initialize
    @middleware = FakeMiddlewareStack.new
  end
end

class FakeRailsApp
  attr_reader :config

  def initialize
    @config = FakeRailsConfig.new
  end

  def self.module_parent_name
    "TestApp"
  end
end

class CampfireIntegrationTest < Minitest::Test
  def teardown
    ExceptionNotifier.unregister_exception_notifier(:campfire)
  end

  def test_rack_configures_the_campfire_notifier
    ExceptionNotification::Rack.new(
      ->(_env) { [ 200, {}, [] ] },
      campfire: { webhook_url: "https://example.com/rooms/1/abc123/messages" }
    )

    assert_instance_of ExceptionNotifier::CampfireNotifier,
      ExceptionNotifier.registered_exception_notifier(:campfire)
  end

  def test_public_entrypoint_loads_without_preloading_the_dependency
    output, status = Open3.capture2e(
      RbConfig.ruby,
      "-Ilib",
      "-e",
      'require "exception_notification/once/campfire"'
    )

    assert_predicate status, :success?, output
  end

  def test_gem_name_entrypoint_loads_without_preloading_the_dependency
    output, status = Open3.capture2e(
      RbConfig.ruby,
      "-Ilib",
      "-e",
      'require "exception_notification-campfire-once"'
    )

    assert_predicate status, :success?, output
  end

  def test_console_loads_the_public_entrypoint
    output, status = Open3.capture2e(
      RbConfig.ruby,
      "-r./test/support/console_irb_stub",
      "bin/console"
    )

    assert_predicate status, :success?, output
  end

  def test_non_rails_app_swallows_webhook_delivery_failures
    output, status = Open3.capture2e(
      RbConfig.ruby,
      "-Ilib",
      "-e",
      <<~RUBY
        require "exception_notification/once/campfire"
        notifier = ExceptionNotifier::CampfireNotifier.new(
          webhook_url: "http://127.0.0.1:1",
          app_name: "TestApp"
        )
        notifier.call(RuntimeError.new("boom"))
      RUBY
    )

    assert_predicate status, :success?, output
  end

  def test_version_includes_the_git_sha_for_source_checkouts
    assert_match(/\A0\.1\.0\.pre\.git\.[0-9a-f]+\z/, ExceptionNotification::Once::Campfire::VERSION)
  end

  def test_gemspec_requires_exception_notification_5_or_newer
    specification = Gem::Specification.load("exception_notification-campfire-once.gemspec")
    dependency = specification.dependencies.find { |item| item.name == "exception_notification" }

    assert_equal Gem::Requirement.new(">= 5.0"), dependency.requirement
  end

  def test_install_registers_campfire_notifier
    fake_app = FakeRailsApp.new
    Rails.stub(:application, fake_app) do
      ExceptionNotification::Once::Campfire.install!(webhook_url: "https://example.com/rooms/1/abc123/messages")
    end
    assert_instance_of ExceptionNotifier::CampfireNotifier,
      ExceptionNotifier.registered_exception_notifier(:campfire)
  end

  def test_install_inserts_rack_middleware
    fake_app = FakeRailsApp.new
    Rails.stub(:application, fake_app) do
      ExceptionNotification::Once::Campfire.install!(webhook_url: "https://example.com/rooms/1/abc123/messages")
    end
    assert fake_app.config.middleware.include?(ExceptionNotification::Rack)
  end

  def test_install_raises_on_unknown_background
    fake_app = FakeRailsApp.new
    Rails.stub(:application, fake_app) do
      assert_raises(ArgumentError) do
        ExceptionNotification::Once::Campfire.install!(
          webhook_url: "https://example.com/rooms/1/abc123/messages",
          background: :unknown
        )
      end
    end
  end
end

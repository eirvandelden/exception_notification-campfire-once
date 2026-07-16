# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "exception_notification"
require "exception_notification/once/campfire"

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

  def test_version_is_stable_for_source_checkouts
    assert_equal "0.1.0", ExceptionNotification::Once::Campfire::VERSION
  end

  def test_gemspec_requires_exception_notification_5_or_newer
    specification = Gem::Specification.load("exception_notification-campfire-once.gemspec")
    dependency = specification.dependencies.find { |item| item.name == "exception_notification" }

    assert_equal Gem::Requirement.new(">= 5.0"), dependency.requirement
  end
end

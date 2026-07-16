# Campfire Notifier Fixes Design

## Goal

Make the gem's documented Campfire notifier configuration work, avoid posting sensitive request data, and restore the default verification command.

## Design

Expose the notifier at `ExceptionNotifier::CampfireNotifier`, the constant name resolved by `exception_notification` for the `campfire:` Rack option. The gem entry point will load that implementation, and the README will demonstrate the standard middleware configuration without manually registering a class.

When formatting an exception from a request, use Rails' filtered parameter API and do not include the session. Keep the existing textual Campfire payload and the existing error-swallowing behavior.

Tests will exercise the public require path, the Rack middleware configuration, and filtered request output. RuboCop configuration or source will be adjusted only as needed for `bundle exec rake` to pass.

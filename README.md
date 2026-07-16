# exception_notification-campfire-once

A Campfire (37signals ONCE) notifier for the `exception_notification` gem. Sends exception notifications to your Campfire chatroom via webhooks.

## Installation

Add to your `Gemfile`:

```ruby
gem "exception_notification-campfire-once", github: "eirvandelden/exception_notification-campfire-once"
```

Then run `bundle install`.

## Usage

Configure the notifier in `config/initializers/exception_notification.rb`:

```ruby
if Rails.env.production?
  Rails.application.config.middleware.use ExceptionNotification::Rack,
    campfire: { webhook_url: ENV.fetch("CAMPFIRE_WEBHOOK_URL") }
end
```

## Options

- **`webhook_url`** (required): The full Campfire bot webhook URL in the format `https://<host>/rooms/:room_id/:bot_key/messages`
- **`app_name`** (optional): Name shown in notifications. Defaults to the Rails application module name.

## License

O'Saasy License. This license permits use, modification, and distribution but
prohibits offering the software as a competing hosted, managed, or SaaS service.
See [LICENSE.md](LICENSE.md) for the complete terms.

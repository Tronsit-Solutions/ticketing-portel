require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TicketingPortal
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "UTC"

    # Active Storage's built-in /rails/active_storage/* routes serve any file
    # to whoever has the link, without checking the session. Attachments are
    # served by TicketAttachmentsController instead, behind login and the
    # same access rules as the ticket.
    config.active_storage.draw_routes = false
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

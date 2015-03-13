require File.expand_path('../boot', __FILE__)

#mongomapper config
# require "action_controller/railtie"
# require "action_mailer/railtie"
# require "active_model/railtie"
# require "action_view/railtie"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

#mongooid config
require "action_controller/railtie"
require "action_mailer/railtie"
#require "active_resource/railtie" # Comment this line for Rails 4.0+
require "rails/test_unit/railtie"
require "sprockets/railtie" # Uncomment this line for Rails 3.1+

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  #Bundler.require(*Rails.groups(:assets => %w(development test)))  #from rails 3.2.x
  Bundler.require(:default, Rails.env)
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module PSTDashboard
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'
    config.action_mailer.logger = Logger.new("./log/mail.log")
    config.action_mailer.logger.level = Logger::INFO
 #  config.action_mailer.delivery_method = :sendmail

   config.action_mailer.delivery_method = :smtp
   config.action_mailer.smtp_settings = {
	   :address =>'mailproxy.aac.va.gov'
   }
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.perform_deliveries = true
 #  config.action_mailer.sendmail_settings = {
 #   :location        => '/usr/sbin/sendmail',
 #   :arguments       => '-i -t'
 # }
  end
end
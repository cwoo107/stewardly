# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Vendored third-party stylesheets (Leaflet), linked only on pages that need them.
Rails.application.config.assets.paths << Rails.root.join("vendor/assets/stylesheets")

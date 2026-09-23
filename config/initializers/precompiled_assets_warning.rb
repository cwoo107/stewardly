# In development, Propshaft serves only what's in public/assets once a manifest is
# there, so new CSS and JavaScript silently stop loading after `assets:precompile`.
if Rails.env.development? && Rails.public_path.join("assets/.manifest.json").exist?
  message = <<~WARNING

    ⚠️  public/assets has precompiled assets, so new CSS and JavaScript won't load in development.
        Run `bin/rails assets:clobber` (and use `bin/dev`, which rebuilds CSS as you go).

  WARNING
  warn message
  Rails.logger&.warn(message)
end

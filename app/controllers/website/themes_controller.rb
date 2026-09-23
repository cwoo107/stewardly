class Website::ThemesController < Website::BaseController
  before_action :require_manage!

  def edit
  end

  def update
    theme = Site::Theme.fetch(params.dig(:site, :theme_key).presence || @site.theme_key)
    definition = SectionDefinition.new(schema: { "settings" => Site::Theme::SETTINGS })
    settings = EmailTemplate::SectionSettings.new(definition, @site.theme_settings).apply(params.fetch(:settings, {}))
    settings = {} if theme.key != @site.theme_key && params[:reset_colors] == "1" # a new theme's own colors
    @site.update!(theme_key: theme.key, theme_settings: settings.compact)
    @site.expire_cache!
    redirect_to edit_website_theme_path, notice: "Theme saved."
  end
end

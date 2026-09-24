class Website::ThemesController < Website::BaseController
  before_action :require_manage!

  def edit
  end

  def update
    theme = Site::Theme.fetch(params.dig(:site, :theme_key).presence || @site.theme_key)
    definition = SectionDefinition.new(schema: { "settings" => theme.settings_schema })
    settings = EmailTemplate::SectionSettings.new(definition, @site.theme_settings).apply(params.fetch(:settings, {}))
    settings = settings.except(*Site::Theme::LOOK) if params[:reset_colors] == "1" # the theme's own colors and fonts; content stays
    @site.update!(theme_key: theme.key, theme_settings: settings.compact)
    new_home = params[:theme_home] == "1" && theme.home_sections.any?
    Site::Starters.install_home!(@site, theme) if new_home
    @site.expire_cache!
    notice = new_home ? "Theme saved. The home page draft now uses #{theme.name}'s design; publish it when you're ready." : "Theme saved."
    redirect_to edit_website_theme_path, notice:
  end
end

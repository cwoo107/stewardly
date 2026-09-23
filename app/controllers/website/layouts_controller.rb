# Advanced mode: the theme layout (header, footer, <head>), as Liquid.
class Website::LayoutsController < Website::BaseController
  before_action :require_develop!

  def edit
  end

  def update
    liquid = params.expect(site: [ :layout_liquid ])[:layout_liquid]
    Email::Liquid.parse(liquid)
    return redirect_to(edit_website_layout_path, alert: "The layout needs {{ content_for_layout }} (where pages go) and {{ head }} (styles and page titles).") unless liquid.include?("content_for_layout") && liquid.include?("head")

    @site.update!(layout_liquid: liquid)
    @site.expire_cache!
    redirect_to edit_website_layout_path, notice: "Layout saved."
  rescue Liquid::Error => error
    flash.now[:alert] = "The layout has an error: #{error.message}"
    @site.layout_liquid = liquid
    render :edit, status: :unprocessable_content
  end

  def destroy
    @site.update!(layout_liquid: nil)
    @site.expire_cache!
    redirect_to edit_website_layout_path, notice: "Back to the #{@site.theme.name} theme's layout.", status: :see_other
  end
end

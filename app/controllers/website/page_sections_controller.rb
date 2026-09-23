class Website::PageSectionsController < Website::BaseController
  before_action :require_manage!
  before_action :set_page

  def create
    entry = @page.add_section!(params.expect(:key))
    redirect_to edit_website_page_section_path(@page, entry["id"]), status: :see_other
  rescue ActiveRecord::RecordNotFound, ArgumentError
    redirect_to website_page_path(@page), alert: "That section can't be added."
  end

  def edit
    @section = @page.section(params[:id]) or raise ActiveRecord::RecordNotFound
    @definition = SectionDefinition.kind_web.find_by!(key: @section["key"])
  end

  def update
    section = @page.section(params[:id]) or raise ActiveRecord::RecordNotFound
    definition = SectionDefinition.kind_web.find_by!(key: section["key"])
    settings = EmailTemplate::SectionSettings.new(definition, section["settings"]).apply(params.fetch(:settings, {}), block_action: params[:block_action])
    @page.update_section!(section["id"], settings)
    if params[:block_action].present?
      redirect_to edit_website_page_section_path(@page, section["id"]), status: :see_other
    else
      redirect_to website_page_path(@page), notice: "#{definition.name} saved to the draft.", status: :see_other
    end
  end

  def destroy
    @page.remove_section!(params[:id])
    redirect_to website_page_path(@page), notice: "Section removed from the draft.", status: :see_other
  end

  def move
    @page.move_section!(params[:id], params.expect(:position))
    head :no_content
  end

  private
    def set_page
      @page = @site.pages.find(params.expect(:page_id))
    end
end

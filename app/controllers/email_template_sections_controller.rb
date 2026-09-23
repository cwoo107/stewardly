# Adding, editing, reordering, and removing a template's sections. Settings forms are
# built from each section's schema.
class EmailTemplateSectionsController < ApplicationController
  before_action :set_template

  def create
    @template.add_section!(params.expect(:key))
    redirect_to @template, status: :see_other
  rescue ActiveRecord::RecordNotFound, ArgumentError
    redirect_to @template, alert: "That section can't be added."
  end

  def edit
    @section = @template.section(params[:id]) or raise ActiveRecord::RecordNotFound
    @definition = SectionDefinition.kind_email.find_by!(key: @section["key"])
  end

  def update
    section = @template.section(params[:id]) or raise ActiveRecord::RecordNotFound
    definition = SectionDefinition.kind_email.find_by!(key: section["key"])
    settings = EmailTemplate::SectionSettings.new(definition, section["settings"]).apply(params.fetch(:settings, {}), block_action: params[:block_action])
    @template.update_section!(section["id"], settings)

    if params[:block_action].present?
      redirect_to edit_email_template_section_path(@template, section["id"]), status: :see_other
    else
      redirect_to @template, notice: "#{definition.name} saved.", status: :see_other
    end
  end

  def destroy
    @template.remove_section!(params[:id])
    redirect_to @template, notice: "Section removed.", status: :see_other
  end

  def move
    @template.move_section!(params[:id], params.expect(:position))
    head :no_content
  end

  private
    def set_template
      @template = EmailTemplate.find(params.expect(:email_template_id))
      authorize @template, :update?
    end
end

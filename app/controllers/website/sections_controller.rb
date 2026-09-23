# Advanced mode: section Liquid and settings schemas, including custom sections.
class Website::SectionsController < Website::BaseController
  before_action :require_develop!
  before_action :set_definition, only: %i[ edit update reset ]

  def index
    skip_policy_scope # the church's own section definitions, authorized by develop_website
    @definitions = SectionDefinition::Defaults.web_sections
  end

  def new
    @definition = SectionDefinition.new(kind: "web", name: "", liquid: STARTER_LIQUID, schema: { "settings" => [ { "id" => "heading", "type" => "text", "label" => "Heading" } ] })
  end

  def create
    @definition = SectionDefinition.new(kind: "web", system: false)
    @definition.assign_attributes(definition_params)
    if @schema_error.nil? && @definition.save
      redirect_to edit_website_section_path(@definition), notice: "Section created. It's now in every page's “Add a section” list."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @definition.assign_attributes(definition_params.merge(customized: @definition.system? || @definition.customized?))
    if @schema_error.nil? && @definition.save
      @site.expire_cache!
      redirect_to edit_website_section_path(@definition), notice: "Section saved. Pages that use it show the change right away."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Built-ins only: back to the shipped Liquid and schema (future updates apply again).
  def reset
    return redirect_to(edit_website_section_path(@definition), alert: "Only built-in sections can be reset.") unless @definition.system?

    @definition.update!(customized: false, schema: @definition.schema.merge("version" => 0))
    SectionDefinition::Defaults.install!("web")
    @site.expire_cache!
    redirect_to edit_website_section_path(@definition), notice: "Back to the original."
  end

  private
    STARTER_LIQUID = <<~LIQUID.freeze
      <section class="site-section px-6 py-16 sm:px-12 lg:px-24">
        <h2 class="site-heading text-3xl font-semibold">{{ settings.heading | escape }}</h2>
      </section>
    LIQUID

    def set_definition
      @definition = SectionDefinition.kind_web.find(params.expect(:id))
    end

    def definition_params
      attributes = params.expect(section_definition: %i[ name key liquid schema_json ])
      schema_json = attributes.delete(:schema_json)
      if schema_json
        attributes[:schema] = JSON.parse(schema_json).merge(@definition&.schema.to_h.slice("version"))
      end
      attributes.delete(:key) if @definition&.persisted?
      attributes
    rescue JSON::ParserError => error
      @schema_error = "The settings schema isn't valid JSON: #{error.message}"
      @definition.errors.add(:base, @schema_error)
      attributes.except(:schema_json)
    end
end

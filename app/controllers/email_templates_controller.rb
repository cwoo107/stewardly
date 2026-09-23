# Email templates. show is the editor: sections on the left, live preview on the right.
class EmailTemplatesController < ApplicationController
  before_action :set_template, only: %i[ show edit update destroy preview test ]

  def index
    authorize EmailTemplate
    @templates = policy_scope(EmailTemplate).alphabetical
  end

  def show
    @definitions = SectionDefinition::Defaults.email_sections.reject { |definition| definition.schema["system_only"] }
  end

  def new
    @template = authorize EmailTemplate.new
  end

  def create
    @template = authorize EmailTemplate.new(template_params)
    if @template.save
      redirect_to @template, notice: "Template created. Add sections to build it."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to @template, notice: "Template saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @template.destroy
      redirect_to email_templates_path, notice: "Template deleted.", status: :see_other
    else
      redirect_to @template, alert: "Campaigns use this template, so it can't be deleted.", status: :see_other
    end
  end

  # The rendered email for the signed-in user's person, loaded into the preview frame.
  def preview
    @html = EmailTemplate::Renderer.new(@template, base_url: request.base_url).preview(preview_person)
    @width = params[:width] == "mobile" ? 375 : 640
    render layout: false
  rescue Liquid::Error, Mrml::Error => error
    @error = error.message
    render layout: false
  end

  def test
    person = preview_person
    return redirect_to(@template, alert: "Your user isn't linked to a person with an email address.") if person&.email.blank?

    CampaignMailer.with(template: @template, person:).test.deliver_later
    redirect_to @template, notice: "A test email is on its way to #{person.email}."
  end

  private
    def set_template
      @template = authorize EmailTemplate.find(params.expect(:id))
    end

    def preview_person = Current.user.person || Person.new(first_name: "Friend", email: Current.user.email_address, church: Current.church)

    def template_params
      params.expect(email_template: [ :name, :subject, :preheader, theme: EmailTemplate::THEME_DEFAULTS.keys ])
    end
end

# Builder: each field is edited inline in its own Turbo Frame.
class FormFieldsController < ApplicationController
  before_action :set_form
  before_action :set_field, only: %i[ show edit update destroy move ]

  def create
    @field = authorize @form.fields.new(field_type: params.expect(:field_type), label: "Untitled question")
    @field.options = [ "Option 1", "Option 2" ] if @field.choice?
    @field.save!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to edit_form_path(@form) }
    end
  end

  def show
  end

  # `add_condition` re-renders the editor with an extra blank condition row (nothing is saved).
  def edit
    @extra_conditions = params[:add_condition].present? ? 1 : 0
  end

  def update
    @field.assign_attributes(field_params)
    if params[:add_condition].present?
      @extra_conditions = 1
      render :edit, status: :unprocessable_content
    elsif @field.save
      render :show
    else
      @extra_conditions = 0
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @field.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@field)) }
      format.html { redirect_to edit_form_path(@form), status: :see_other }
    end
  end

  def move
    @field.reposition(params.expect(:position))
    head :no_content
  end

  private
    def set_form
      @form = policy_scope(Form).includes(:fields).find(params.expect(:form_id))
    end

    def set_field
      @field = authorize @form.fields.find(params.expect(:id))
    end

    def field_params
      params.expect(form_field: [ :label, :help_text, :required, :sensitive, :maps_to, :options_text,
        visibility_rule: [ :match, conditions: [ [ :field, :operator, :value, :_destroy ] ] ] ]).then do |attributes|
        options = attributes.delete(:options_text)
        options.nil? ? attributes : attributes.merge(options: options.split("\n"))
      end
    end
end

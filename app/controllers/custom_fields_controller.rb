class CustomFieldsController < ApplicationController
  before_action :set_custom_field, only: %i[ edit update destroy move ]

  def index
    authorize CustomField
    @custom_fields = policy_scope(CustomField).ordered
  end

  def new
    @custom_field = authorize CustomField.new(field_type: "text")
  end

  def create
    @custom_field = authorize CustomField.new(custom_field_params)
    if @custom_field.save
      redirect_to custom_fields_path, notice: "Custom field added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @custom_field.update(custom_field_params.except(:key, :field_type))
      redirect_to custom_fields_path, notice: "Custom field saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @custom_field.destroy!
    redirect_to custom_fields_path, notice: "Custom field deleted, along with its values.", status: :see_other
  end

  # Drag-and-drop reorder from the settings list.
  def move
    @custom_field.reposition(params.expect(:position))
    head :no_content
  end

  private
    def set_custom_field
      @custom_field = authorize policy_scope(CustomField).find(params.expect(:id))
    end

    def custom_field_params
      params.expect(custom_field: [ :label, :key, :field_type, :options_text ]).then do |attributes|
        options = attributes.delete(:options_text)
        options.nil? ? attributes : attributes.merge(options: options.split("\n"))
      end
    end
end

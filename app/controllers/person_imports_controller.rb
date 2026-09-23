# Upload a CSV → check the preview and map columns → import in a background job.
class PersonImportsController < ApplicationController
  before_action :set_import, only: %i[ show edit update ]

  def index
    authorize PersonImport
    @imports = policy_scope(PersonImport).recent_first.includes(created_by: :person).limit(25)
  end

  def new
    @import = authorize PersonImport.new
  end

  def create
    @import = authorize PersonImport.new(file: params.dig(:person_import, :file), created_by: Current.user)
    if @import.save
      redirect_to edit_person_import_path(@import)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    return redirect_to(@import) unless @import.pending?

    @preview = PersonImport::Preview.new(@import)
    @mapping = @import.mapping.presence || @preview.suggested_mapping
  end

  def update
    return redirect_to(@import) unless @import.pending?

    if @import.update(mapping: params.expect(person_import: [ mapping: {} ])[:mapping].to_h, status: :queued)
      PersonImportJob.perform_later(@import)
      redirect_to @import, notice: "Import started."
    else
      @preview = PersonImport::Preview.new(@import)
      @mapping = @import.mapping
      @import.status = :pending
      render :edit, status: :unprocessable_content
    end
  end

  def show
  end

  private
    def set_import
      @import = authorize policy_scope(PersonImport).find(params.expect(:id))
    end
end

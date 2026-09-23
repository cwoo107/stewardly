class FormsController < ApplicationController
  before_action :set_form, only: %i[ show edit update destroy publish close preview ]

  def index
    authorize Form
    @forms = policy_scope(Form).alphabetical
    @submission_counts = policy_scope(FormSubmission).group(:form_id).count
  end

  # Submissions live under the form; its page is the builder for form managers.
  def show
    redirect_to policy(@form).update? ? edit_form_path(@form) : form_submissions_path(@form)
  end

  def new
    @form = authorize Form.new
  end

  def create
    @form = authorize Form.new(form_params)
    if @form.save
      redirect_to edit_form_path(@form), notice: "Form created. Add some fields."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @form.update(form_params.except(:purpose))
      redirect_to edit_form_path(@form), notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @form.destroy
      redirect_to forms_path, notice: "Form deleted.", status: :see_other
    else
      redirect_to edit_form_path(@form), alert: "Forms with submissions can't be deleted. Close it instead.", status: :see_other
    end
  end

  def publish
    @form.publish!
    redirect_to edit_form_path(@form), notice: "Published. It's live at #{public_form_url(@form.slug)}.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to edit_form_path(@form), alert: @form.errors.full_messages.to_sentence, status: :see_other
  end

  def close
    @form.close!
    redirect_to edit_form_path(@form), notice: "Closed. The form no longer accepts submissions.", status: :see_other
  end

  # The public form, logic and all, without submitting.
  def preview
    @preview = true
    render "public_forms/show", layout: "public"
  end

  private
    def set_form
      @form = authorize policy_scope(Form).includes(:fields).find(params.expect(:id))
    end

    def form_params
      params.expect(form: %i[ name slug description confirmation_message purpose access ])
    end
end

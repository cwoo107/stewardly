class FormSubmissionsController < ApplicationController
  before_action :set_form

  def index
    authorize FormSubmission.new(form: @form)
    submissions = policy_scope(FormSubmission).where(form: @form).includes(:person).recent_first
    @status = params[:status].presence_in(FormSubmission.statuses.keys) || "received"

    respond_to do |format|
      format.html { @pagy, @submissions = pagy(submissions.where(status: @status)) }
      format.csv do
        export = FormSubmission::Export.new(@form, submissions, include_sensitive: policy(FormSubmission.new(form: @form)).show_sensitive?)
        send_data export.to_csv, filename: export.filename, type: :csv
      end
    end
  end

  def show
    @submission = authorize policy_scope(FormSubmission).where(form: @form).includes(:person, uploads_attachments: :blob).find(params.expect(:id))
  end

  def update
    @submission = authorize policy_scope(FormSubmission).where(form: @form).find(params.expect(:id))
    @submission.update!(status: params.expect(form_submission: [ :status ])[:status])
    redirect_to form_submission_path(@form, @submission), notice: "Marked #{@submission.status}.", status: :see_other
  end

  private
    def set_form
      @form = policy_scope(Form).includes(:fields).find(params.expect(:form_id))
    end
end

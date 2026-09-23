class FormSubmissionJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(form_submission)
    FormSubmission::Processing.new(form_submission).process!
  end
end

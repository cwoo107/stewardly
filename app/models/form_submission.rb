class FormSubmission < ApplicationRecord
  belongs_to :form, inverse_of: :submissions
  belongs_to :person, optional: true
  belongs_to :user, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many_attached :uploads
  has_one :prayer_request, dependent: :nullify

  enum :status, { received: "received", reviewed: "reviewed", archived: "archived" }, default: :received, validate: true

  # Answers to fields marked sensitive (e.g. prayer text) never sit in plain jsonb.
  serialize :sensitive_answers, coder: JSON
  encrypts :sensitive_answers

  after_create_commit -> { FormSubmissionJob.perform_later(self) }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  # Builds a submission from a valid Form::Response, attaching uploads.
  def self.build_from(form, response, **attributes)
    form.submissions.new(answers: response.answers, sensitive_answers: response.sensitive_answers.presence, **attributes).tap do |submission|
      response.uploads.each do |key, upload|
        blob = ActiveStorage::Blob.create_and_upload!(io: upload, filename: upload.original_filename, content_type: upload.content_type)
        submission.uploads.attach(blob)
        submission.answers[key] = { "filename" => blob.filename.to_s, "blob_id" => blob.id }
      end
    end
  end

  def answer_for(field)
    field.sensitive? ? sensitive_answers.to_h[field.key] : answers[field.key]
  end

  def upload_for(field)
    blob_id = answers.dig(field.key, "blob_id") or return
    uploads.find { |attachment| attachment.blob_id == blob_id }
  end

  def processed? = processed_at.present?

  def sensitive? = sensitive_answers.present?
end

require "csv"

# CSV of a form's submissions. Sensitive answers are left out unless the viewer may see them.
class FormSubmission::Export
  def initialize(form, submissions, include_sensitive:)
    @form = form
    @submissions = submissions
    @fields = form.fields.reject { |field| field.sensitive? && !include_sensitive }
  end

  def to_csv
    CSV.generate do |csv|
      csv << [ "Submitted at", "Person", "Status" ] + @fields.map(&:label)
      @submissions.each do |submission|
        csv << [ submission.created_at.iso8601, submission.person&.full_name, submission.status ] +
          @fields.map { |field| field.display_answer(submission.answer_for(field)) }
      end
    end
  end

  def filename
    "#{@form.slug}-submissions-#{Date.current.iso8601}.csv"
  end
end

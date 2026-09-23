# Submissions to prayer forms are prayer requests, so they follow prayer permissions;
# everything else needs view_form_submissions.
class FormSubmissionPolicy < ApplicationPolicy
  def index? = read?
  def show? = read?
  def update? = read?
  def export? = read?
  def show_sensitive? = record.form.prayer_request_form? ? can?(:manage_prayer_requests) : can?(:manage_forms)

  private
    def read? = record.form.prayer_request_form? ? can?(:manage_prayer_requests) : can?(:view_form_submissions)

  class Scope < Scope
    def resolve
      purposes = []
      purposes << "general" if can?(:view_form_submissions)
      purposes << "prayer_request" if can?(:manage_prayer_requests)
      scope.where(form_id: Form.where(purpose: purposes).select(:id))
    end
  end
end

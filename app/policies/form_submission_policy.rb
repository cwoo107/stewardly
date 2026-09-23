# Submissions to prayer forms are prayer requests, so they follow prayer permissions;
# benevolence forms follow benevolence permissions (and are read on the case, where
# views are audited); everything else needs view_form_submissions.
class FormSubmissionPolicy < ApplicationPolicy
  def index? = read?
  def show? = read?
  def update? = read?
  def export? = read? && !record.form.benevolence_request_form?

  def show_sensitive?
    return can?(:manage_prayer_requests) if record.form.prayer_request_form?
    return false if record.form.benevolence_request_form? # shown on the case instead

    can?(:manage_forms)
  end

  private
    def read?
      return can?(:manage_prayer_requests) if record.form.prayer_request_form?
      return can?(:view_benevolence) if record.form.benevolence_request_form?

      can?(:view_form_submissions)
    end

  class Scope < Scope
    def resolve
      purposes = []
      purposes << "general" if can?(:view_form_submissions)
      purposes << "prayer_request" if can?(:manage_prayer_requests)
      purposes << "benevolence_request" if can?(:view_benevolence)
      scope.where(form_id: Form.where(purpose: purposes).select(:id))
    end
  end
end

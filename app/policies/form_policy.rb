class FormPolicy < ApplicationPolicy
  # People who read submissions reach them through the forms list.
  def index? = can?(:manage_forms) || can?(:view_form_submissions) || can?(:manage_prayer_requests)
  def show? = can?(:manage_forms) || FormSubmissionPolicy.new(user, FormSubmission.new(form: record)).index?
  def create? = can?(:manage_forms)
  def update? = can?(:manage_forms)
  def publish? = update?
  def close? = update?
  def preview? = update?
  def destroy? = can?(:manage_forms)

  class Scope < Scope
    def resolve
      return scope.all if can?(:manage_forms)

      purposes = []
      purposes << "general" if can?(:view_form_submissions)
      purposes << "prayer_request" if can?(:manage_prayer_requests)
      scope.where(purpose: purposes)
    end
  end
end

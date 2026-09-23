# The report assistant, saved reports, and metrics. Conversations and saved reports are
# personal; each tool also checks its own permission.
class ReportPolicy < ApplicationPolicy
  def index? = can?(:use_reports)
  def create? = can?(:use_reports)
  def show? = can?(:use_reports) && owned?
  def update? = show?
  def destroy? = show?
  def rerun? = show?

  private
    def owned? = record.is_a?(Class) || record.is_a?(Symbol) || record.user_id == user.id

  class Scope < Scope
    def resolve
      can?(:use_reports) ? scope.where(user:) : scope.none
    end
  end
end

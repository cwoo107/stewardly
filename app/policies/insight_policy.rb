class InsightPolicy < ApplicationPolicy
  def index? = can?(:view_insights)
  def update? = can?(:view_insights) && Insight.visible_to(user).exists?(record.id)
  def resolve? = update?
  def dismiss? = update?
  def snooze? = update?
  def assign? = update?

  class Scope < Scope
    def resolve
      can?(:view_insights) ? scope.visible_to(user) : scope.none
    end
  end
end

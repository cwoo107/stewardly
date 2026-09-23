# manage_prayer_requests (pastoral staff) sees every request. view_prayer_requests
# (prayer team) sees prayer-team and shared requests, plus any assigned to them.
class PrayerRequestPolicy < ApplicationPolicy
  def index? = manage? || can?(:view_prayer_requests)
  def show? = manage? || (can?(:view_prayer_requests) && (!record.pastoral_staff? || assigned?))
  def create? = index?
  def update? = manage?
  def destroy? = manage?
  def follow_up? = show? && record.person.present?
  def assign? = manage?

  private
    def manage? = can?(:manage_prayer_requests)
    def assigned? = user.present? && record.prayer_assignments.any? { |assignment| assignment.user_id == user.id }

  class Scope < Scope
    def resolve
      return scope.all if can?(:manage_prayer_requests)
      return scope.none unless can?(:view_prayer_requests)

      scope.visible_to_prayer_team.or(scope.where(id: PrayerAssignment.where(user:).select(:prayer_request_id)))
    end
  end
end

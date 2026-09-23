class AnnouncementPolicy < ApplicationPolicy
  def index? = can?(:manage_announcements)
  def create? = can?(:manage_announcements)
  def update? = can?(:manage_announcements)
  def destroy? = can?(:manage_announcements)

  class Scope < Scope
    def resolve = can?(:manage_announcements) ? scope.all : scope.none
  end
end

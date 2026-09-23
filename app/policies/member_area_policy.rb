# Headless: every signed-in user has the member area.
class MemberAreaPolicy < ApplicationPolicy
  def show? = user.present?
end

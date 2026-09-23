class UserRolePolicy < ApplicationPolicy
  # Only church admins may hand out (or take away) church admin, so
  # manage_users alone cannot be used to escalate privileges.
  def create? = can?(:manage_users) && (!record.role.church_admin? || user.church_admin?)
  def destroy? = create?
end

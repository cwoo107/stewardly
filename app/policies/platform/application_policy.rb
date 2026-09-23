# Platform policies receive a PlatformAdmin, never a church User.
class Platform::ApplicationPolicy < ApplicationPolicy
  private
    def platform_admin? = user.is_a?(PlatformAdmin)

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.is_a?(PlatformAdmin) ? scope.all : scope.none
    end
  end
end

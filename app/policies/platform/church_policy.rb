class Platform::ChurchPolicy < Platform::ApplicationPolicy
  def index? = platform_admin?
  def create? = platform_admin?

  class Scope < Platform::ApplicationPolicy::Scope
  end
end

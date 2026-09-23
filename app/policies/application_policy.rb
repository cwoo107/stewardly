# Deny by default. Policies grant access through User#can? and permission keys.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  private
    def can?(permission)
      user.present? && user.can?(permission)
    end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Records are already limited to the current church by acts_as_tenant.
    def resolve
      scope.none
    end

    private
      attr_reader :user, :scope

      def can?(permission)
        user.present? && user.can?(permission)
      end
  end
end

class AuditEventPolicy < ApplicationPolicy
  def index? = can?(:view_audit_log)

  class Scope < Scope
    def resolve
      can?(:view_audit_log) ? scope.all : scope.none
    end
  end
end

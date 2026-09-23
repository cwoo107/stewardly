class AttendanceForecastPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve = can?(:view_attendance) ? scope.all : scope.none
  end
end

# Headless: the staff calendar is for anyone who uses the admin screens.
class CalendarPolicy < ApplicationPolicy
  def show? = user.present? && user.admin_area?
end

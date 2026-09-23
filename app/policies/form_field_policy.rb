class FormFieldPolicy < ApplicationPolicy
  def show? = can?(:manage_forms)
  def create? = can?(:manage_forms)
  def update? = can?(:manage_forms)
  def move? = update?
  def destroy? = can?(:manage_forms)
end

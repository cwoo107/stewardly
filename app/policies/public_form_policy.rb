# Anyone, signed in or not, may view and submit a published form. A closed form
# still shows its page (saying it's closed); drafts don't exist publicly.
class PublicFormPolicy < ApplicationPolicy
  def show? = !record.draft?
  def create? = record.published?
  def thanks? = show?
end

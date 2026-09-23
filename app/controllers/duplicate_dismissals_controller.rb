class DuplicateDismissalsController < ApplicationController
  def create
    authorize :duplicate, :dismiss?
    people = policy_scope(Person).find(params.expect(duplicate_dismissal: %i[ person_id other_person_id ]).values)
    DuplicateDismissal.find_or_create_by!(person: people.first, other_person: people.last) { |d| d.dismissed_by = Current.user }
    redirect_to duplicates_path, notice: "Marked as different people.", status: :see_other
  end
end

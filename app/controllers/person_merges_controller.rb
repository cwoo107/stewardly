# Merges a duplicate into the person in the URL (the survivor).
class PersonMergesController < ApplicationController
  before_action :set_people

  def new
  end

  def create
    Person::Merge.new(survivor: @person, duplicate: @duplicate).merge!
    redirect_to @person, notice: "Merged #{@duplicate.name} into #{@person.name}.", status: :see_other
  rescue Person::Merge::Error => error
    redirect_to new_person_merge_path(@person, duplicate_id: @duplicate.id), alert: error.message, status: :see_other
  end

  private
    def set_people
      @person = authorize policy_scope(Person).find(params.expect(:person_id)), :merge?
      @duplicate = policy_scope(Person).find(params.expect(:duplicate_id))
    end
end

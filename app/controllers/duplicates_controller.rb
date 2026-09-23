class DuplicatesController < ApplicationController
  def index
    authorize :duplicate
    # Not a relation: DuplicateFinder queries the current church directly, and
    # manage_people (checked above) already covers every person it returns.
    skip_policy_scope
    @pairs = Person::DuplicateFinder.new.pairs
  end
end

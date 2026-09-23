# The member area (/me): everything a signed-in person sees about themselves.
# Records are always reached through Current.person, so members only ever touch their own.
class Member::BaseController < ApplicationController
  layout "member"

  before_action { authorize :member_area, :show? }
  # Lists here are always the signed-in person's own records (or published church
  # content), so there's no broader collection to scope.
  skip_after_action :verify_policy_scoped

  helper_method :person

  private
    def person = Current.user.person
    def today = Current.church.today
end

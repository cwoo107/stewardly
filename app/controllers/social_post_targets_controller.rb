class SocialPostTargetsController < ApplicationController
  before_action :set_target

  def retry
    @target.retry!
    redirect_to @target.social_post, notice: "Trying #{@target.social_account.label} again."
  end

  def mark_posted
    @target.mark_posted!(permalink: params[:permalink])
    redirect_to @target.social_post, notice: "Marked as posted.", status: :see_other
  end

  private
    def set_target
      post = SocialPost.find(params.expect(:social_post_id))
      authorize post, :show?
      @target = post.targets.find(params.expect(:id))
      raise Pundit::NotAuthorizedError unless @target.failed? || @target.unknown?
    end
end

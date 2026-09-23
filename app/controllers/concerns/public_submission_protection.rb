# Shared by public, no-sign-in endpoints (forms, event registration):
# per-IP rate limits, a honeypot field, and a minimum fill time. Suspected bots get
# the normal success response and nothing is saved.
#
#   include PublicSubmissionProtection
#   protect_submissions only: :create, with: -> { render :show, status: :too_many_requests }
module PublicSubmissionProtection
  extend ActiveSupport::Concern

  MINIMUM_FILL_TIME = 2.seconds
  HONEYPOT = :website

  class_methods do
    def protect_submissions(only:, with:)
      rate_limit to: 5, within: 1.minute, only: only, name: "public-minute", with: with
      rate_limit to: 30, within: 1.hour, only: only, name: "public-hour", with: with
    end
  end

  def self.started_at_token
    Rails.application.message_verifier(:public_submissions).generate(Time.current.to_f, expires_in: 1.day)
  end

  private
    def suspected_bot?
      started = Rails.application.message_verifier(:public_submissions).verified(params[:started_at].to_s)
      bot = params[HONEYPOT].present? || started.nil? || Time.current.to_f - started.to_f < minimum_fill_time
      Rails.logger.info("[public submissions] dropped a suspected bot submission to #{request.path}") if bot
      bot
    end

    def minimum_fill_time = PublicSubmissionProtection::MINIMUM_FILL_TIME
end

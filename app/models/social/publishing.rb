# Publishes one target, at most once.
#
# The target is locked and moved pending → publishing before calling the network, then
# the result is recorded. If the process dies during the call, the target stays
# "publishing"; the sweeper later marks such targets "unknown" rather than retrying, so a
# post can never go out twice. Staff check the network and choose "It posted" or "Retry".
# Errors the network calls transient retry with backoff; others fail right away.
class Social::Publishing
  STUCK_AFTER = 15.minutes

  def initialize(target)
    @target = target
  end

  def publish!
    return unless claim!

    photo_urls = self.class.photo_urls(@target.social_post)
    result = @target.social_account.provider.publish(@target, photo_urls:)
    @target.update!(status: :published, external_post_id: result.external_post_id, permalink: result.permalink, published_at: Time.current, error: nil)
  rescue Social::Provider::Error => error
    record_failure(error)
  ensure
    @target.social_post.settle! if @target.persisted? && !@target.pending?
  end

  # Targets left "publishing" by a crashed job: the outcome is unknown, so never retry them automatically.
  def self.mark_stuck!
    SocialPostTarget.publishing.where(updated_at: ...STUCK_AFTER.ago).find_each do |target|
      target.update!(status: :unknown, error: "We lost track of this one mid-publish. Check #{target.social_account.network_label} to see whether it went out.")
      target.social_post.settle!
    end
  end

  # Meta downloads photos from a public URL, so they're served from the church's website address.
  def self.photo_urls(post)
    base = Site.current.base_url
    post.media.map { |file| "#{base}#{Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)}" }
  end

  private
    def claim!
      @target.with_lock do
        next false unless @target.pending? && @target.social_post.status.in?(%w[ scheduled publishing ])

        @target.update!(status: :publishing, attempts: @target.attempts + 1)
        @target.social_post.update!(status: :publishing) if @target.social_post.scheduled?
        true
      end
    end

    def record_failure(error)
      if error.reconnect
        @target.social_account.update!(status: :needs_reconnect, last_error: error.message.first(255))
      end

      if error.transient && @target.attempts < SocialPostTarget::MAX_ATTEMPTS
        wait = SocialPostTarget::BACKOFF.fetch(@target.attempts - 1, SocialPostTarget::BACKOFF.last)
        @target.update!(status: :pending, next_attempt_at: wait.from_now, error: "#{error.message} (will try again)")
      else
        @target.update!(status: :failed, error: error.message.first(1000), next_attempt_at: nil)
      end
    end
end

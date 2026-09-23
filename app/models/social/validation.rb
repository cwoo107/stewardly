# What stops a post going out, per network (shown in the composer and checked before scheduling).
class Social::Validation
  def initialize(post)
    @post = post
  end

  def problems
    problems = []
    targets = @post.targets.reject(&:marked_for_destruction?)
    problems << "Choose at least one account" if targets.empty?
    problems << "Write something" if @post.body.blank? && @post.media.none?
    photos = @post.media.size
    targets.each do |target|
      account = target.social_account
      limits = Social::Providers::Meta.limits(account.network)
      caption = target.caption_text.to_s
      problems << "#{account.label} needs a photo" if limits.photo_required && photos.zero?
      problems << "#{account.label} allows #{limits.max_photos} photos at most" if photos > limits.max_photos
      problems << "#{account.label} allows #{limits.caption_length} characters (this is #{caption.length})" if caption.length > limits.caption_length
      problems << "#{account.label} needs reconnecting" unless account.connected?
    end
    problems.uniq
  end
end

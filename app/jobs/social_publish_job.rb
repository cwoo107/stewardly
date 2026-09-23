class SocialPublishJob < ApplicationJob
  queue_as :default

  def perform(target)
    Social::Publishing.new(target).publish!
  end
end

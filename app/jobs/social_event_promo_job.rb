class SocialEventPromoJob < ApplicationJob
  queue_as :low

  def perform(event)
    Social::EventPromo.new(event).draft!
  end
end

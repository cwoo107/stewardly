class ReportAnswerJob < ApplicationJob
  queue_as :default

  def perform(message)
    Reports::Assistant.new(message).answer! if message.pending?
  end
end

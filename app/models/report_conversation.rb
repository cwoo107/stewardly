class ReportConversation < ApplicationRecord
  belongs_to :user
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :messages, -> { order(:created_at, :id) }, class_name: "ReportMessage", dependent: :destroy

  validates :title, presence: true

  scope :recent_first, -> { order(updated_at: :desc) }

  # Adds the question and a pending answer the assistant fills in (ReportAnswerJob).
  def ask!(question)
    transaction do
      messages.create!(role: "user", content: question)
      answer = messages.create!(role: "assistant", status: "pending")
      touch
      answer
    end.tap { |answer| ReportAnswerJob.perform_later(answer) }
  end
end

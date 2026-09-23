# A church update shown on the member area home page.
class Announcement < ApplicationRecord
  belongs_to :author, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :title, :body, presence: true

  scope :current, ->(now = Time.current, today = now.to_date) {
    where(published_at: ..now).where("expires_on IS NULL OR expires_on >= ?", today).order(pinned: :desc, published_at: :desc)
  }
  scope :recent_first, -> { order(Arel.sql("published_at DESC NULLS FIRST"), created_at: :desc) }

  def published? = published_at.present? && published_at <= Time.current
end

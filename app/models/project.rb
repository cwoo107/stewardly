class Project < ApplicationRecord
  acts_as_tenant :church

  has_many :tasks, dependent: :nullify

  validates :name, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :alphabetical, -> { order(:name) }

  def archived? = archived_at.present?
end

# One gift, synced from the giving provider. Read-only here: only who it's matched to
# can change. Amounts are integer cents with a currency.
class Donation < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :fund, optional: true
  belongs_to :matched_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  encrypts :donor_name, :donor_email

  enum :status, { succeeded: "succeeded", refunded: "refunded", failed: "failed" }, default: :succeeded, validate: true
  enum :match_status, { auto: "auto", manual: "manual", unmatched: "unmatched", ignored: "ignored" }, default: :unmatched,
    validate: true, prefix: :match

  validates :external_id, presence: true, uniqueness: { scope: %i[ church_id provider ] }
  validates :amount_cents, numericality: { only_integer: true }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }

  scope :counted, -> { succeeded } # what totals include
  scope :recent_first, -> { order(given_on: :desc, id: :desc) }
  scope :in_review, -> { match_unmatched }

  def amount = Money.new(amount_cents, currency)

  # Matching by hand also teaches a donor link, so this donor's next gift matches itself.
  def match_to!(person, by: Current.user)
    transaction do
      update!(person:, match_status: :manual, matched_by: by, matched_at: Time.current)
      if donor_external_id.present?
        link = DonorLink.find_or_initialize_by(provider:, donor_external_id:)
        link.update!(person:, created_by: link.created_by || by)
        Donation.where(provider:, donor_external_id:).match_unmatched.where.not(id:)
          .update_all(person_id: person.id, match_status: "auto", matched_at: Time.current)
      end
    end
  end

  # Leaves this gift, and the same donor's other waiting gifts, unmatched on purpose.
  def ignore!(by: Current.user)
    gifts = donor_external_id.present? ? Donation.match_unmatched.where(provider:, donor_external_id:).or(Donation.where(id:)) : Donation.where(id:)
    gifts.update_all(person_id: nil, match_status: "ignored", matched_by_id: by&.id, matched_at: Time.current)
  end
end

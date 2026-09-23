# The review queue: donations nobody could be matched to automatically.
class DonationMatchesController < ApplicationController
  before_action :set_donation, only: %i[ update ignore create_person ]

  # One card per donor (their earliest waiting gift): matching it matches the rest.
  def index
    authorize Donation, :match?
    waiting = policy_scope(Donation).in_review
    donor_key = Arel.sql("COALESCE(donor_external_id, 'gift-' || id::text)")
    firsts = waiting.select(Arel.sql("DISTINCT ON (#{donor_key}) id")).reorder(donor_key, :given_on, :id)
    @pagy, @donations = pagy(waiting.where(id: firsts).includes(:fund).order(:given_on))
    @waiting_by_donor = waiting.where.not(donor_external_id: nil).group(:donor_external_id).count
    @waiting_total_by_donor = waiting.where.not(donor_external_id: nil).group(:donor_external_id).sum(:amount_cents)
  end

  def update
    person = Person.unmerged.find(params.expect(:person_id))
    @donation.match_to!(person)
    redirect_to donation_matches_path, notice: "Matched to #{person.name}. Future gifts from this donor will match automatically."
  end

  def ignore
    @donation.ignore!
    redirect_to donation_matches_path, notice: "Left unmatched.", status: :see_other
  end

  # A giver the church didn't know yet.
  def create_person
    first, *rest = @donation.donor_name.to_s.split
    person = Person.create!(first_name: first.presence || "Unknown", last_name: rest.join(" ").presence || "Giver",
      email: @donation.donor_email.presence, membership_status: :guest)
    @donation.match_to!(person)
    redirect_to donation_matches_path, notice: "Added #{person.name} and matched the gift."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to donation_matches_path, alert: error.record.errors.full_messages.to_sentence
  end

  private
    def set_donation
      @donation = policy_scope(Donation).find(params.expect(:id))
      authorize @donation, :match?
    end
end

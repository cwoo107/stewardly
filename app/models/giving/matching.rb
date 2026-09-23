# Finds the person a donation belongs to: a known donor link first, then exactly one
# person with the donor's email. Anything else waits in the review queue.
class Giving::Matching
  def initialize(donation)
    @donation = donation
  end

  # The person, or nil (left unmatched). Never changes a manual match or an ignored gift.
  def match!
    return @donation.person unless @donation.match_unmatched?

    person = by_link || by_email
    return unless person

    @donation.update!(person:, match_status: :auto, matched_at: Time.current)
    learn_link(person)
    person
  end

  # Likely people for the review queue: same email, then similar names.
  def suggestions(limit: 5)
    people = Person.where(merged_into_id: nil)
    by_email = @donation.donor_email.present? ? people.where(email: @donation.donor_email.downcase).to_a : []
    name = @donation.donor_name.to_s.strip
    similar = name.present? ? people.where("similarity(first_name || ' ' || last_name, ?) > 0.3", name)
      .order(Arel.sql(Person.sanitize_sql_array([ "similarity(first_name || ' ' || last_name, ?) DESC", name ]))).limit(limit).to_a : []
    (by_email + similar).uniq.first(limit)
  end

  private
    def by_link
      return if @donation.donor_external_id.blank?

      DonorLink.find_by(provider: @donation.provider, donor_external_id: @donation.donor_external_id)&.person
    end

    def by_email
      email = @donation.donor_email.to_s.strip.downcase
      return if email.blank?

      people = Person.where(merged_into_id: nil, email:).limit(2).to_a
      people.one? ? people.first : nil
    end

    def learn_link(person)
      return if @donation.donor_external_id.blank?

      DonorLink.create_with(person:).find_or_create_by!(provider: @donation.provider, donor_external_id: @donation.donor_external_id)
    rescue ActiveRecord::RecordNotUnique
      nil
    end
end

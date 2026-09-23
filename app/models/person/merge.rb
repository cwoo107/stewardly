# Folds `duplicate` into `survivor`: memberships, tags, touchpoints, prayer
# requests, and a login account move over; blank details are filled in. The
# duplicate is kept (merged_into, hidden everywhere) so history still resolves.
class Person::Merge
  class Error < StandardError; end

  FILLABLE = %w[ nickname email phone birthdate household_id ].freeze

  attr_reader :survivor, :duplicate

  def initialize(survivor:, duplicate:)
    @survivor = survivor
    @duplicate = duplicate
  end

  def merge!
    raise Error, "A person can't be merged into themselves" if survivor == duplicate
    raise Error, "#{duplicate.name} has already been merged" if duplicate.merged? || survivor.merged?
    raise Error, "Both people have login accounts. Remove one account first." if survivor.user && duplicate.user

    Person.transaction do
      fill_blank_details
      move_unique(Tagging, :tag_id)
      move_unique(GroupMembership, :group_id)
      move_unique(TeamMembership, :team_id)
      Touchpoint.where(person: duplicate).update_all(person_id: survivor.id)
      PrayerRequest.where(person: duplicate).update_all(person_id: survivor.id)
      [ Donation, DonorLink, BenevolenceCase ].each { |model| model.where(person: duplicate).update_all(person_id: survivor.id) }
      # update_all, then reset: saving `duplicate` would otherwise re-save its cached
      # has_one :user and point the login back at the duplicate.
      User.where(person_id: duplicate.id).update_all(person_id: survivor.id)
      duplicate.association(:user).reset
      DuplicateDismissal.where(person: duplicate).or(DuplicateDismissal.where(other_person: duplicate)).delete_all
      duplicate.merged_people.update_all(merged_into_id: survivor.id)

      duplicate.update!(merged_into: survivor, merged_at: Time.current)
      AuditEvent.record!(action: "person.merged", auditable: survivor,
        metadata: { merged_person_id: duplicate.id, merged_person_name: duplicate.full_name, survivor_name: survivor.full_name })
    end
    survivor
  end

  private
    def fill_blank_details
      FILLABLE.each do |attribute|
        survivor[attribute] = duplicate[attribute] if survivor[attribute].blank?
      end
      survivor.custom_fields = duplicate.custom_fields.merge(survivor.custom_fields.compact_blank)
      survivor.save!
    end

    # Moves rows to the survivor, dropping ones the survivor already has (same tag, group, team).
    def move_unique(model, key)
      existing = model.where(person: survivor).pluck(key)
      model.where(person: duplicate, key => existing).delete_all
      model.where(person: duplicate).update_all(person_id: survivor.id)
    end
end

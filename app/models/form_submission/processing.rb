# Applies a submission: links a person, fills in their details from mapped fields,
# creates a prayer request or benevolence case for those forms, and logs a touchpoint.
# Safe to repeat.
#
# Person matching and the fill-blanks rule live in Person::Intake.
class FormSubmission::Processing
  PERSON_ATTRIBUTES = %w[ first_name last_name nickname email phone birthdate ].freeze

  def initialize(submission)
    @submission = submission
    @form = submission.form
  end

  def process!
    return if @submission.processed?

    FormSubmission.transaction do
      person = link_person
      if person
        apply_person_details(person)
        apply_address(person)
        # Benevolence requests stay off the timeline: only benevolence permissions may know about them.
        unless @form.benevolence_request_form?
          person.touchpoints.create!(kind: :form_submission, subject: @submission, summary: "Submitted #{@form.name}",
            occurred_at: @submission.created_at, sensitive: @submission.sensitive?)
        end
      end
      create_prayer_request(person) if @form.prayer_request_form?
      create_benevolence_case(person) if person && @form.benevolence_request_form?
      @submission.update!(person:, processed_at: Time.current)
    end
    Workflow::Events.publish("form_submitted", person: @submission.person, subject: @submission) unless @form.benevolence_request_form?
  end

  private
    def own_submission? = intake.own?

    def mapped(target)
      field = @form.field_for(target) or return
      @submission.answer_for(field)
    end

    def intake
      @intake ||= Person::Intake.new(user: @submission.user, email: mapped("person.email"),
        first_name: mapped("person.first_name"), last_name: mapped("person.last_name"))
    end

    def link_person = intake.person

    def apply_person_details(person)
      intake.update(person, PERSON_ATTRIBUTES.index_with { |attribute| mapped("person.#{attribute}") })
      person.custom_fields = person.custom_fields.merge(custom_values(person))
      person.save! if person.changed?
    end

    # Mapped custom field answers that cast cleanly; ones that don't fit are skipped, not fatal.
    def custom_values(person)
      definitions = CustomField.all.index_by(&:key)

      @form.fields.each_with_object({}) do |field, values|
        next unless field.maps_to&.start_with?("person.custom.")

        definition = definitions[field.maps_to.delete_prefix("person.custom.")] or next
        next if !own_submission? && person.custom_fields.key?(definition.key)

        value = definition.cast(@submission.answer_for(field))
        values[definition.key] = value unless value.nil?
      rescue CustomField::InvalidValue
        next
      end
    end

    def apply_address(person)
      address = mapped("household.address")
      return if address.blank?

      attributes = { address_line1: address["line1"], address_line2: address["line2"], city: address["city"],
        region: address["region"], postal_code: address["postal_code"] }
      household = person.household

      if household.nil?
        person.update!(household: Household.create!(attributes.merge(name: "The #{person.last_name} household")))
      elsif own_submission? || household.address_line1.blank?
        household.update!(attributes)
      end
    end

    def create_benevolence_case(person)
      return if BenevolenceCase.exists?(form_submission: @submission)

      category = BenevolenceCase::NEEDS.key(mapped("benevolence.need_category")) || mapped("benevolence.need_category").to_s.parameterize(separator: "_")
      BenevolenceCase.create!(form_submission: @submission, person:, source: :form,
        summary: mapped("benevolence.summary").to_s.presence || "Request from #{@form.name}",
        circumstances: mapped("benevolence.circumstances"),
        need_category: BenevolenceCase::NEEDS.key?(category) ? category : "other",
        requested_cents: [ Money.parse_cents(mapped("benevolence.amount")).to_i, 0 ].max)
    end

    def create_prayer_request(person)
      body = mapped("prayer_request.body")
      return if body.blank?

      share = mapped("prayer_request.share_with_prayer_team") == true
      PrayerRequest.create!(
        form_submission: @submission, person:, body:, source: :form, visibility: share ? :prayer_team : :pastoral_staff,
        requester_name: person ? nil : [ mapped("person.first_name"), mapped("person.last_name") ].compact_blank.join(" ").presence || "Anonymous",
        requester_email: person ? nil : mapped("person.email"))
    end
end

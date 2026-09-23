# One rule in a segment definition. Each type knows its attributes, how to
# validate them, how to describe itself, and how to become a WHERE clause on
# people. Clauses use EXISTS subqueries so a segment is always one SQL query.
class Segment::Condition
  METERS_PER_MILE = 1609.344

  TYPES = {
    "tag" => "Tags",
    "membership_status" => "Membership status",
    "group" => "Group membership",
    "team" => "Team membership",
    "age" => "Age",
    "custom_field" => "Custom field",
    "distance" => "Lives within a distance",
    "no_touchpoint" => "No contact recently"
  }.freeze

  ATTRIBUTES = {
    "tag" => %w[ operator tag_ids ],
    "membership_status" => %w[ statuses ],
    "group" => %w[ operator group_ids group_type ],
    "team" => %w[ operator team_ids ],
    "age" => %w[ min max ],
    "custom_field" => %w[ key value ],
    "distance" => %w[ miles campus_id latitude longitude ],
    "no_touchpoint" => %w[ days ]
  }.freeze

  LIST_ATTRIBUTES = %w[ tag_ids statuses group_ids team_ids ].freeze

  attr_reader :type, :attributes

  def initialize(attributes)
    attributes = attributes.to_h.stringify_keys
    @type = attributes["type"].to_s
    @attributes = Array(ATTRIBUTES[@type]).to_h { |name| [ name, normalize(name, attributes[name]) ] }
  end

  def [](name) = attributes[name.to_s]

  def to_h
    { "type" => type }.merge(attributes.compact_blank)
  end

  def errors
    return [ "has an unknown type" ] unless TYPES.key?(type)

    send("#{type}_errors")
  end

  def valid? = errors.empty?

  def relation
    send("#{type}_relation")
  end

  def label
    TYPES.fetch(type, type)
  end

  # Plain-language description, e.g. "Tagged any of: Volunteer, Newcomer".
  def summary
    case type
    when "tag"
      names = Tag.where(id: ids("tag_ids")).alphabetical.pluck(:name).join(", ")
      { "any" => "Tagged any of: #{names}", "all" => "Tagged all of: #{names}", "none" => "Not tagged: #{names}" }
        .fetch(operator(%w[ any all none ], "any"))
    when "membership_status" then "Status is #{self["statuses"].map(&:humanize).to_sentence(two_words_connector: " or ", last_word_connector: ", or ")}"
    when "group" then membership_summary("group", Group.where(id: ids("group_ids")).pluck(:name), self["group_type"]&.humanize&.downcase)
    when "team" then membership_summary("team", Team.where(id: ids("team_ids")).pluck(:name), nil)
    when "age" then [ ("at least #{self["min"]}" if self["min"]), ("at most #{self["max"]}" if self["max"]) ].compact.join(" and ").prepend("Age ")
    when "custom_field" then "#{custom_field&.label || self["key"]} is #{self["value"]}"
    when "distance"
      from = self["campus_id"].present? ? Campus.find_by(id: self["campus_id"])&.name : "the chosen point"
      "Lives within #{self["miles"]} miles of #{from}"
    when "no_touchpoint" then "No contact in the last #{self["days"]} days"
    else label
    end
  end

  private
    def normalize(name, value)
      if LIST_ATTRIBUTES.include?(name)
        Array(value).map(&:to_s).compact_blank
      else
        value.is_a?(String) ? value.strip.presence : value
      end
    end

    def people = Person.unmerged

    def membership_summary(noun, names, kind)
      target = names.any? ? names.join(", ") : [ "any", kind, noun ].compact.join(" ")
      operator(%w[ in not_in ], "in") == "in" ? "In #{target}" : "Not in #{target}"
    end

    def integer(name) = Integer(self[name], exception: false)
    def number(name) = Float(self[name], exception: false)
    def ids(name) = self[name].map(&:to_i)

    def operator(allowed, default)
      allowed.include?(self["operator"]) ? self["operator"] : default
    end

    # --- tag: operator any | all | none, tag_ids

    def tag_errors
      self["tag_ids"].empty? ? [ "choose at least one tag" ] : []
    end

    def tag_relation
      tagged = Tagging.where("taggings.person_id = people.id").where(tag_id: ids("tag_ids"))
      case operator(%w[ any all none ], "any")
      when "any" then people.where(tagged.arel.exists)
      when "none" then people.where.not(tagged.arel.exists)
      when "all"
        tag_count = tagged.select(Arel.sql("count(DISTINCT taggings.tag_id)"))
        people.where("(#{tag_count.to_sql}) = ?", ids("tag_ids").uniq.size)
      end
    end

    # --- membership_status: statuses

    def membership_status_errors
      unknown = self["statuses"] - Person.membership_statuses.keys
      return [ "choose at least one status" ] if self["statuses"].empty?

      unknown.any? ? [ "has unknown statuses" ] : []
    end

    def membership_status_relation
      people.where(membership_status: self["statuses"])
    end

    # --- group: operator in | not_in, group_ids (blank = any group), group_type (optional)

    def group_errors
      return [ "has an unknown group type" ] if self["group_type"] && !Group.group_types.key?(self["group_type"])

      []
    end

    def group_relation
      memberships = GroupMembership.joins(:group).where("group_memberships.person_id = people.id").merge(Group.active)
      memberships = memberships.where(group_id: ids("group_ids")) if self["group_ids"].any?
      memberships = memberships.where(groups: { group_type: self["group_type"] }) if self["group_type"]

      operator(%w[ in not_in ], "in") == "in" ? people.where(memberships.arel.exists) : people.where.not(memberships.arel.exists)
    end

    # --- team: operator in | not_in, team_ids (blank = any team)

    def team_errors = []

    def team_relation
      memberships = TeamMembership.where("team_memberships.person_id = people.id")
      memberships = memberships.where(team_id: ids("team_ids")) if self["team_ids"].any?

      operator(%w[ in not_in ], "in") == "in" ? people.where(memberships.arel.exists) : people.where.not(memberships.arel.exists)
    end

    # --- age: min and/or max, in whole years, as of today in the church's time zone

    def age_errors
      min, max = integer("min"), integer("max")
      return [ "needs a minimum or maximum age" ] if min.nil? && max.nil?
      return [ "minimum can't be above maximum" ] if min && max && min > max

      []
    end

    def age_relation
      today = ActsAsTenant.current_tenant.today
      relation = people.where.not(birthdate: nil)
      relation = relation.where(birthdate: ..(today - integer("min").years)) if integer("min")
      relation = relation.where(birthdate: (today - (integer("max") + 1).years + 1.day)..) if integer("max")
      relation
    end

    # --- custom_field: key, value (multi-select matches when the value is one of the choices)

    def custom_field_errors
      field = custom_field
      return [ "choose a custom field" ] unless field
      return [ "needs a value" ] if self["value"].blank?

      field.cast(self["value"])
      []
    rescue CustomField::InvalidValue => error
      [ "value #{error.message}" ]
    end

    def custom_field_relation
      field = custom_field
      value = field.cast(self["value"])

      if field.field_type == "multi_select"
        people.where("people.custom_fields -> :key @> :value::jsonb", key: field.key, value: value.to_json)
      else
        people.where("people.custom_fields -> :key = :value::jsonb", key: field.key, value: value.to_json)
      end
    end

    def custom_field
      @custom_field ||= CustomField.find_by(key: self["key"]) if self["key"]
    end

    # --- distance: miles from a campus or a latitude/longitude

    def distance_errors
      return [ "needs a distance in miles" ] unless number("miles")&.positive?
      return [ "needs a campus or a point" ] unless origin

      []
    end

    def distance_relation
      in_range = Household.where("households.id = people.household_id")
        .where("ST_DWithin(households.location, ST_GeogFromText(:origin), :meters)",
          origin: origin.as_text.prepend("SRID=4326;"), meters: number("miles") * METERS_PER_MILE)
      people.where(in_range.arel.exists)
    end

    def origin
      if self["campus_id"].present?
        Campus.find_by(id: self["campus_id"])&.location
      elsif number("latitude") && number("longitude")
        Geocodable::POINT_FACTORY.point(number("longitude"), number("latitude"))
      end
    end

    # --- no_touchpoint: days

    def no_touchpoint_errors
      integer("days")&.positive? ? [] : [ "needs a number of days" ]
    end

    def no_touchpoint_relation
      recent = Touchpoint.where("touchpoints.person_id = people.id").where(occurred_at: integer("days").days.ago..)
      people.where.not(recent.arel.exists)
    end
end

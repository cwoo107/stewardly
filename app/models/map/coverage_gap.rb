# Households with no active group meeting within `miles`: where a new group would help.
class Map::CoverageGap
  def initialize(miles:)
    @meters = miles.to_f * Segment::Condition::METERS_PER_MILE
  end

  def households
    nearby_group = Group.active.located.where("ST_DWithin(groups.location, households.location, ?)", @meters)
    Household.located.where.not(nearby_group.arel.exists)
  end

  def people
    Person.unmerged.where(household_id: households.select(:id))
  end
end

# Builds the points the map draws: campuses, groups, and households, with
# household privacy applied in SQL. Users without view_precise_locations see
# households clustered on a ~1 km grid with counts, never exact points or names.
class Map::Layers
  def initialize(user:, segment: nil, group_type: nil, coverage_gap: false, stage: nil)
    @user = user
    @segment = segment
    @stage = stage
    @group_type = group_type.presence
    @coverage_gap = coverage_gap
    @church = ActsAsTenant.current_tenant
  end

  def to_h
    { campuses:, groups:, households:, precise: precise?, coverage_miles: @church.group_coverage_miles }
  end

  def precise? = @user.can?(:view_precise_locations)

  def campuses
    Campus.located.ordered.map { |campus| { name: campus.name, lat: campus.latitude, lng: campus.longitude } }
  end

  def groups
    scope = Group.active.located.alphabetical
    scope = scope.where(group_type: @group_type) if @group_type
    scope.map { |group| { id: group.id, name: group.name, type: group.group_type.humanize, lat: group.latitude, lng: group.longitude } }
  end

  def households
    precise? ? precise_households : approximate_households
  end

  private
    def household_scope
      scope = Household.located
      scope = scope.where(id: @segment.people.select(:household_id)) if @segment
      scope = scope.where(id: Person.unmerged.joins(:pathway_placement).where(pathway_placements: { pathway_stage_id: @stage.id }).select(:household_id)) if @stage
      scope = Map::CoverageGap.new(miles: @church.group_coverage_miles).households.merge(scope) if @coverage_gap
      scope
    end

    def precise_households
      household_scope.order(:id).map { |household| { id: household.id, name: household.name, lat: household.latitude, lng: household.longitude } }
    end

    def approximate_households
      grid = Household::APPROXIMATE_GRID_DEGREES
      household_scope.reorder(nil).group(Arel.sql("1, 2")).pluck(
        Arel.sql("ST_Y(ST_SnapToGrid(households.location::geometry, #{grid}))"),
        Arel.sql("ST_X(ST_SnapToGrid(households.location::geometry, #{grid}))"),
        Arel.sql("count(*)")
      ).map { |lat, lng, count| { lat: lat.to_f, lng: lng.to_f, count: } }
    end
end

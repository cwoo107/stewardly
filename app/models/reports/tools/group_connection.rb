# How many people who joined in a period are in a group, and how many of those who
# aren't live near an active group (PostGIS).
class Reports::Tools::GroupConnection < Reports::Tool
  METERS_PER_MILE = 1609.344

  self.tool_name = "group_connection"
  self.title = "Group connection"
  self.description = "Of the people added to the church database in a date range: how many are in an active group, the connection rate, and how many unconnected people live within a distance of an active group."
  self.permission = "view_people"
  self.parameters = {
    joined_from: { type: "string", format: "date", description: "Start of the joined date range (YYYY-MM-DD). Default: January 1 this year.", label: "Joined from", default: -> { @today.beginning_of_year } },
    joined_to: { type: "string", format: "date", description: "End of the joined date range (YYYY-MM-DD). Default: today.", label: "Joined to", default: -> { @today } },
    miles: { type: "integer", description: "Distance in miles to count as near an active group. Default: the church's coverage radius.", label: "Miles", default: -> { @church.group_coverage_miles } }
  }

  private
    def call(args)
      from, to, miles = args.values_at("joined_from", "joined_to", "miles")
      joined = Person.unmerged.where(created_at: from.in_time_zone(@church.zone).beginning_of_day..to.in_time_zone(@church.zone).end_of_day)
      connected_ids = GroupMembership.joins(:group).merge(Group.active).select(:person_id)
      connected = joined.where(id: connected_ids)
      unconnected = joined.where.not(id: connected_ids)
      near = unconnected.joins(:household).where(<<~SQL.squish, meters: miles * METERS_PER_MILE).count
        households.location IS NOT NULL AND EXISTS (SELECT 1 FROM groups WHERE groups.church_id = households.church_id
        AND groups.active AND groups.location IS NOT NULL AND ST_DWithin(groups.location, households.location, :meters))
      SQL
      total = joined.count
      Result.build(figures: {
        "People who joined" => total, "In a group" => connected.count, "Connected (%)" => percent(connected.count, total),
        "Not in a group" => unconnected.count, "Not in a group, within #{miles} miles of an active group" => near
      }, note: "Joined #{from} to #{to}.")
    end
end

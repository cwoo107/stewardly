module Reports::Tools
  def self.all
    [ PathwayFunnel, GroupConnection, AttendanceSeries, FirstTimeGuests, VolunteerCoverage, VolunteerLoad, CampaignPerformance,
      WorkflowPerformance, PeopleCounts, GivingSummary, PrivateAreaTotals ]
  end

  def self.available(user, church) = all.select { |tool| tool.available_to?(user, church) }
  def self.find(name, user:, church:) = available(user, church).find { |tool| tool.tool_name == name.to_s }
end

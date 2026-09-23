# How heavily each volunteer is serving, and whether that's too little or too much.
# Loads the assignment history once for a set of people, then assesses anyone as of
# any date, optionally with one more assignment ("what if we schedule them then?").
#
#   loads = Volunteering::LoadAssessment.new(people:, church:)
#   loads.for(person, as_of: date)                   # => Result
#   loads.for(person, as_of: date, extra_date: date) # with one more assignment that day
class Volunteering::LoadAssessment
  LEVELS = %w[ underused healthy elevated at_risk ].freeze
  LEVEL_LABELS = { "underused" => "Underused", "healthy" => "Healthy", "elevated" => "Elevated", "at_risk" => "At risk" }.freeze
  LOOKBACK_WEEKS = 12
  RATE_WEEKS = 8

  # Church settings override these (Church#volunteer_load_thresholds).
  DEFAULT_THRESHOLDS = {
    "at_risk_consecutive_weeks" => 6.0, "at_risk_per_week" => 1.5, "at_risk_teams" => 4.0,
    "elevated_consecutive_weeks" => 4.0, "elevated_per_week" => 1.0, "elevated_teams" => 3.0,
    "elevated_decline_rate" => 0.5, "decline_min_requests" => 3.0, "underused_weeks" => 8.0
  }.freeze

  THRESHOLD_LABELS = {
    "at_risk_consecutive_weeks" => "At risk: weeks in a row", "at_risk_per_week" => "At risk: assignments a week",
    "at_risk_teams" => "At risk: teams", "elevated_consecutive_weeks" => "Elevated: weeks in a row",
    "elevated_per_week" => "Elevated: assignments a week", "elevated_teams" => "Elevated: teams",
    "elevated_decline_rate" => "Elevated: share of requests declined (0–1)", "decline_min_requests" => "Declines count after this many requests",
    "underused_weeks" => "Underused: weeks without serving"
  }.freeze

  Result = Data.define(:person_id, :consecutive_weeks, :per_week, :teams, :decline_rate, :weeks_since_served, :level, :reasons) do
    def label = LEVEL_LABELS.fetch(level)
    def at_risk? = level == "at_risk"
  end

  def initialize(people:, church:)
    @person_ids = Array(people).map { |person| person.respond_to?(:id) ? person.id : person }
    @church = church
    @thresholds = church.load_thresholds
  end

  def for(person, as_of:, extra_date: nil)
    person_id = person.respond_to?(:id) ? person.id : person
    dates = active_dates(person_id)
    dates = (dates + [ extra_date ]).sort if extra_date
    dates = dates.select { |date| date <= as_of }

    # Weeks in a row, counting back from this week, or from last week if they haven't served yet this week.
    weeks_served = dates.map { |date| week_of(date) }.uniq.to_set
    latest = weeks_served.include?(week_of(as_of)) ? week_of(as_of) : week_of(as_of) - 7
    consecutive = 0
    consecutive += 1 while weeks_served.include?(latest - (consecutive * 7))
    per_week = dates.count { |date| date > as_of - (RATE_WEEKS * 7) } / RATE_WEEKS.to_f
    answered = responses(person_id).select { |date, _| date <= as_of && date > as_of - (LOOKBACK_WEEKS * 7) }
    declines = answered.count { |_, status| status == "declined" }
    decline_rate = answered.size >= t("decline_min_requests") ? declines.to_f / answered.size : nil
    weeks_since = dates.last && ((as_of - dates.last) / 7).floor
    teams = team_counts[person_id].to_i

    level, reasons = rate(consecutive:, per_week:, teams:, decline_rate:, weeks_since:, joined: joined_on[person_id], as_of:)
    Result.new(person_id:, consecutive_weeks: consecutive, per_week: per_week.round(2), teams:, decline_rate: decline_rate&.round(2),
      weeks_since_served: weeks_since, level:, reasons:)
  end

  private
    def t(key) = @thresholds.fetch(key)
    def week_of(date) = date.beginning_of_week(:sunday)

    def rate(consecutive:, per_week:, teams:, decline_rate:, weeks_since:, joined:, as_of:)
      at_risk = [
        ("#{consecutive} weeks in a row" if consecutive >= t("at_risk_consecutive_weeks")),
        ("#{per_week.round(1)} assignments a week" if per_week >= t("at_risk_per_week")),
        ("on #{teams} teams" if teams >= t("at_risk_teams"))
      ].compact
      return [ "at_risk", at_risk ] if at_risk.any?

      elevated = [
        ("#{consecutive} weeks in a row" if consecutive >= t("elevated_consecutive_weeks")),
        ("#{per_week.round(1)} assignments a week" if per_week >= t("elevated_per_week")),
        ("on #{teams} teams" if teams >= t("elevated_teams")),
        ("declined #{(decline_rate * 100).round}% of recent requests" if decline_rate && decline_rate >= t("elevated_decline_rate"))
      ].compact
      return [ "elevated", elevated ] if elevated.any?

      on_team_long_enough = joined && (as_of - joined) >= t("underused_weeks") * 7
      if teams.positive? && on_team_long_enough && (weeks_since.nil? || weeks_since >= t("underused_weeks"))
        return [ "underused", [ weeks_since ? "not scheduled in #{weeks_since} weeks" : "never scheduled" ] ]
      end

      [ "healthy", [] ]
    end

    # Non-declined assignment dates, oldest first.
    def active_dates(person_id) = history.fetch(person_id, []).reject { |_, status| status == "declined" }.map(&:first)

    # [date, status] for answered requests.
    def responses(person_id) = history.fetch(person_id, []).select { |_, status| status.in?(%w[ accepted declined ]) }

    def history
      @history ||= Assignment.where(person_id: @person_ids).where(local_date: (@church.today - 2.years)..)
        .order(:local_date).pluck(:person_id, :local_date, :status).group_by(&:first).transform_values { |rows| rows.map { |_, date, status| [ date, status ] } }
    end

    def team_counts = @team_counts ||= TeamMembership.where(person_id: @person_ids).group(:person_id).count

    def joined_on
      @joined_on ||= TeamMembership.where(person_id: @person_ids).group(:person_id).minimum(:created_at).transform_values { |at| at.in_time_zone(@church.zone).to_date }
    end
end

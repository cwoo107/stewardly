# The pathway dashboard's numbers.
class Pathway::Funnel
  WINDOW = 12.months

  def initialize(pathway, now: Time.current)
    @pathway = pathway
    @stages = PathwayStage.where(pathway:).ordered.to_a
    @now = now
  end

  attr_reader :stages

  # stage => people there now
  def counts
    @counts ||= begin
      counts = PathwayPlacement.joins(:person).merge(Person.unmerged).group(:pathway_stage_id).count
      @stages.to_h { |stage| [ stage, counts[stage.id].to_i ] }
    end
  end

  # Of the people who entered a stage in the last 12 months, the share who later reached the next.
  #   { stage => { entered:, moved_on:, percent: } } for every stage but the last
  def conversions
    @stages.each_cons(2).to_h do |stage, following|
      entered = entries_into(stage)
      moved_on = entered.count { |person_id, at| reached_after?(person_id, following, at) }
      [ stage, { entered: entered.size, moved_on:, percent: entered.empty? ? nil : (moved_on * 100.0 / entered.size).round } ]
    end
  end

  # Median days from entering a stage to entering the next, for people who moved on.
  def median_days
    @stages.each_cons(2).to_h do |stage, following|
      days = entries_into(stage).filter_map do |person_id, at|
        next_at = first_entry_after(person_id, following, at)
        ((next_at - at) / 1.day).round if next_at
      end.sort
      [ stage, days.empty? ? nil : days[days.size / 2] ]
    end
  end

  def stuck
    PathwayPlacement.stuck.joins(:person).merge(Person.unmerged).includes(:person, :pathway_stage).order(:entered_at)
  end

  # Moves per month: { "Forward" => { month => n }, "Back" => { month => n } }
  def movement(months: 12)
    from = (@now.to_date << (months - 1)).beginning_of_month
    scope = PathwayTransition.where(occurred_at: from.beginning_of_day..@now)
    %w[ forward back ].to_h do |direction|
      [ direction.humanize, scope.where(direction:).group_by_month(:occurred_at, range: from.beginning_of_day..@now, format: "%b %Y").count ]
    end
  end

  private
    # [person_id, entered_at] for entries (placed or moved in) during the window.
    def entries_into(stage)
      transitions.select { |t| t.to_stage_id == stage.id && t.occurred_at >= @now - WINDOW }.map { |t| [ t.person_id, t.occurred_at ] }.uniq(&:first)
    end

    def reached_after?(person_id, stage, at) = first_entry_after(person_id, stage, at).present?

    def first_entry_after(person_id, stage, at)
      by_person[person_id].to_a.find { |t| t.to_stage_id == stage.id && t.occurred_at > at }&.occurred_at
    end

    def transitions
      @transitions ||= PathwayTransition.where(occurred_at: (@now - WINDOW - 2.years)..@now).order(:occurred_at).select(:person_id, :to_stage_id, :occurred_at).to_a
    end

    def by_person = @by_person ||= transitions.group_by(&:person_id)
end

# Church-wide attendance trends for the dashboard, all services combined.
class Attendance::Growth
  def initialize(today:)
    @today = today
  end

  # { week start (Sunday) => total } for the last `weeks` weeks.
  def weekly(weeks: 52)
    from = (@today - (weeks * 7)).beginning_of_week(:sunday)
    counts.where(service_occurrences: { local_date: from..@today })
      .group_by_week("service_occurrences.local_date", week_start: :sunday, time_zone: false, range: from..@today).sum(:total)
  end

  def rolling(series, weeks)
    values = series.values
    series.keys.each_with_index.to_h do |week, index|
      window = values[[ index - weeks + 1, 0 ].max..index].reject(&:zero?)
      [ week, window.empty? ? nil : (window.sum.to_f / window.size).round ]
    end
  end

  # Average weekly attendance this year so far vs the same stretch last year.
  def year_to_date
    this_year = average_week(@today.beginning_of_year..@today)
    last_year = average_week(@today.beginning_of_year.prev_year..@today.prev_year)
    change = this_year && last_year&.positive? ? ((this_year - last_year) * 100.0 / last_year) : nil
    { this_year:, last_year:, change: }
  end

  # Average weekly attendance by month, this year and last.
  def monthly_by_year
    [ @today.year - 1, @today.year ].to_h do |year|
      months = (1..12).filter_map do |month|
        range = Date.new(year, month).all_month
        next if range.first > @today

        [ Date::ABBR_MONTHNAMES[month], average_week(range) ]
      end
      [ year.to_s, months.to_h ]
    end
  end

  # First-time guests per month: counted at the door plus first-time check-ins.
  def first_time_guests(months: 12)
    from = (@today << (months - 1)).beginning_of_month
    counted = counts.where(service_occurrences: { local_date: from..@today })
      .group_by_month("service_occurrences.local_date", time_zone: false, range: from..@today, format: "%b %Y").sum(:first_time_guests)
    checked_in = Attendance.where(first_time: true).joins(:service_occurrence).where(service_occurrences: { local_date: from..@today })
      .group_by_month("service_occurrences.local_date", time_zone: false, range: from..@today, format: "%b %Y").count
    counted.merge(checked_in) { |_, a, b| a + b }
  end

  private
    def counts
      AttendanceCount.joins(:service_occurrence).where(service_occurrences: { cancelled: false })
    end

    # Weekly totals (week starting Sunday => total) for this year and last, in one query.
    def week_totals
      @week_totals ||= counts.where(service_occurrences: { local_date: Date.new(@today.year - 1, 1, 1)..@today })
        .group(Arel.sql("(date_trunc('week', service_occurrences.local_date + 1) - interval '1 day')::date")).sum(:total)
    end

    def average_week(range)
      totals = week_totals.select { |week, _| range.cover?(week) }.values
      totals.empty? ? nil : (totals.sum.to_f / totals.size).round
    end
end

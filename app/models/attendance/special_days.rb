# What makes a service date unusual: built-in holidays (Easter computed in code,
# the rest from the holidays gem) plus the church's own SpecialSundays.
#
#   Attendance::SpecialDays.new(church).for(date) # => [Day(key: "easter", label: "Easter", ...)]
class Attendance::SpecialDays
  Day = Data.define(:key, :label, :default_multiplier, :override_percent) do
    def override_multiplier = override_percent && (1 + override_percent / 100.0)
  end

  # Typical effects, used until a church has its own history for a kind of day.
  DEFAULTS = {
    "easter" => [ "Easter", 1.6 ], "palm_sunday" => [ "Palm Sunday", 1.1 ],
    "christmas" => [ "Christmas Sunday", 1.3 ], "new_years" => [ "New Year's weekend", 0.8 ],
    "mothers_day" => [ "Mother's Day", 1.15 ], "fathers_day" => [ "Father's Day", 0.95 ],
    "memorial_day_weekend" => [ "Memorial Day weekend", 0.85 ], "independence_day_weekend" => [ "Independence Day weekend", 0.85 ],
    "labor_day_weekend" => [ "Labor Day weekend", 0.88 ], "thanksgiving_weekend" => [ "Thanksgiving weekend", 0.9 ]
  }.freeze

  def initialize(church)
    @church = church
    @marked = {}
  end

  def for(date)
    built_in(date).map { |key| day(key) } + marked(date)
  end

  def special?(date) = self.for(date).any?

  private
    def day(key)
      label, multiplier = DEFAULTS.fetch(key)
      Day.new(key:, label:, default_multiplier: multiplier, override_percent: nil)
    end

    def built_in(date)
      easter = Attendance::Easter.on(date.year)
      keys = []
      keys << "easter" if date == easter
      keys << "palm_sunday" if date == easter - 7
      keys << "christmas" if date.month == 12 && date.day.between?(19, 25)
      keys << "new_years" if (date.month == 12 && date.day >= 26) || (date.month == 1 && date.day == 1)
      keys << "mothers_day" if named?(date, "Mother's Day")
      keys << "fathers_day" if named?(date, "Father's Day")
      keys << "memorial_day_weekend" if named?(date + 1, "Memorial Day")
      keys << "labor_day_weekend" if named?(date + 1, "Labor Day")
      keys << "thanksgiving_weekend" if named?(date - 3, "Thanksgiving")
      keys << "independence_day_weekend" if ((date - 3)..(date + 3)).cover?(Date.new(date.year, 7, 4))
      keys
    end

    def named?(date, name)
      Holidays.on(date, :us, :informal).any? { |holiday| holiday[:name] == name }
    end

    def marked(date)
      @marked[date.year] ||= SpecialSunday.where(local_date: date.all_year).index_by(&:local_date)
      special = @marked[date.year][date] or return []

      [ Day.new(key: "church:#{special.key}", label: special.name, default_multiplier: 1.0, override_percent: special.expected_change_percent) ]
    end
end

class Reports::Tools::PeopleCounts < Reports::Tool
  AGE_BANDS = [ [ "Under 13", 0..12 ], [ "13–17", 13..17 ], [ "18–29", 18..29 ], [ "30–49", 30..49 ], [ "50–64", 50..64 ], [ "65+", 65..200 ] ].freeze

  self.tool_name = "people_counts"
  self.title = "People"
  self.description = "How many people the church knows, broken down by membership status, age band, or adult/child."
  self.permission = "view_people"
  self.parameters = { by: { type: "string", enum: %w[ membership_status age_band household_role ], description: "How to break down the count. Default: membership_status.", label: "Break down by", default: "membership_status" } }

  private
    def call(args)
      people = Person.unmerged
      rows = case args["by"]
      when "age_band"
        ages = people.where.not(birthdate: nil).pluck(:birthdate).map { |birthdate| Person.new(birthdate:, church: @church).age(on: @today) }
        AGE_BANDS.map { |label, range| [ label, ages.count { |age| range.cover?(age) } ] } + [ [ "Unknown", people.where(birthdate: nil).count ] ]
      when "household_role" then people.group(:household_role).count.map { |role, count| [ role.to_s.humanize, count ] }
      else people.group(:membership_status).count.map { |status, count| [ status.to_s.humanize, count ] }
      end
      Result.build(figures: { "People" => people.count }, tables: [ table("By #{args["by"].humanize.downcase}", [ args["by"].humanize, "People" ], rows) ])
    end
end

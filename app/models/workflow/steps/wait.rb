# Waits for a duration, until a date, or until the next chosen weekday at a time
# (all in the church's time zone).
class Workflow::Steps::Wait < Workflow::Steps::Base
  UNITS = { "hours" => "hours", "days" => "days", "weeks" => "weeks" }.freeze
  MODES = { "duration" => "For a length of time", "date" => "Until a date", "weekday" => "Until the next day of the week" }.freeze

  self.label = "Wait"
  self.default_config = { "mode" => "duration", "amount" => 1, "unit" => "days", "time" => "09:00" }

  def errors
    case config["mode"]
    when "duration" then config["amount"].to_i.between?(1, 365) && UNITS.key?(config["unit"]) ? [] : [ "needs an amount (1–365)" ]
    when "date" then (Date.iso8601(config["date"].to_s) rescue nil) ? [] : [ "needs a date" ]
    when "weekday" then config["weekday"].to_s.match?(/\A[0-6]\z/) ? [] : [ "needs a day of the week" ]
    else [ "needs a kind of wait" ]
    end
  end

  def summary
    case config["mode"]
    when "date" then "Wait until #{config["date"]}"
    when "weekday" then "Wait until #{Date::DAYNAMES[config["weekday"].to_i]} at #{config["time"]}"
    else "Wait #{config["amount"]} #{config["amount"].to_i == 1 ? config["unit"].to_s.singularize : config["unit"]}"
    end
  end

  def perform(_run, execution)
    wake_at = execution.result["wake_at"]&.then { |value| Time.zone.parse(value) } || wake_time
    Time.current >= wake_at ? Outcome.done("waited_until" => wake_at.iso8601) : Outcome.wait(wake_at, "wake_at" => wake_at.iso8601)
  end

  private
    def wake_time(now = church.now)
      hour, minute = config["time"].to_s.split(":").map(&:to_i)
      case config["mode"]
      when "date" then church.zone.parse(config["date"]).change(hour: hour.to_i, min: minute.to_i)
      when "weekday"
        days = (config["weekday"].to_i - now.wday) % 7
        candidate = (now + days.days).change(hour: hour.to_i, min: minute.to_i)
        candidate <= now ? candidate + 1.week : candidate
      else now + config["amount"].to_i.public_send(config["unit"])
      end
    end
end

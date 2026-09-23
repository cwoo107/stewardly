# What templates may see. Each drop exposes a fixed list of fields.
module Email::Drops
  class Person < Liquid::Drop
    def initialize(person) = @person = person
    def first_name = @person.nickname.presence || @person.first_name
    def last_name = @person.last_name
    def name = @person.name
    def email = @person.email
  end

  class Church < Liquid::Drop
    def initialize(church) = @church = church
    def name = @church.name
    def mailing_address = @church.mailing_address.to_s
    def website = "https://#{@church.host}"
    def giving_url = @church.giving_url.to_s
  end

  class Event < Liquid::Drop
    def initialize(occurrence, url) = (@occurrence, @url = occurrence, url)
    def title = @occurrence.title
    # Always the church's time zone: campaigns compile in jobs, outside any request's zone.
    def date = I18n.l(starts_at.to_date, format: :long)
    def time = starts_at.strftime("%-l:%M %p")
    def location = @occurrence.event.location_summary
    def url = @url

    private
      def starts_at = @occurrence.starts_at.in_time_zone(@occurrence.church.zone)
  end

  class Links < Liquid::Drop
    def initialize(unsubscribe:, preferences:, token: "")
      @unsubscribe, @preferences, @token = unsubscribe, preferences, token
    end

    def unsubscribe = @unsubscribe
    def preferences = @preferences
    def token = @token
  end

  # Stands in for per-recipient values while a campaign's HTML is compiled once:
  # {{ person.first_name }} renders as the literal "{{ person.first_name }}" for the
  # per-recipient pass to fill in.
  class Placeholder < Liquid::Drop
    def initialize(name) = @name = name
    def liquid_method_missing(method) = "{{ #{@name}.#{method} }}"
  end
end

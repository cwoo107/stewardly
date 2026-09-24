# What site Liquid can see. Only these drops, never models: public church info, the
# navigation, and public data (published public events, active groups, service times,
# published public forms). Groups show their town, never a street address.
module Site::Drops
  class Site < Liquid::Drop
    def initialize(site, page:, base_url:)
      @site = site
      @page = page
      @base_url = base_url
    end

    def name = @site.name
    def url = @base_url
    def tagline = @site.settings["tagline"].to_s
    def footer_text = @site.settings["footer_text"].to_s
    # The website's own logo (Theme settings), or else the church's logo (Settings).
    def logo_url
      @logo_url ||= begin
        source = @site.settings["logo_url"].presence
        source ||= Email::ImageSource.stored_value(@site.church.logo.blob) if @site.church.logo.attached?
        Email::ImageSource.new(source, base_url: @base_url, width: @site.settings["logo_width"]).resolve&.url.to_s
      end
    end
    def logo_width = @site.settings["logo_width"]
    def facebook_url = @site.settings["facebook_url"].to_s
    def instagram_url = @site.settings["instagram_url"].to_s
    def youtube_url = @site.settings["youtube_url"].to_s
    def nav = @nav ||= @site.nav_pages.map { |page| NavLink.new(page.title, page.path, page.id == @page&.id) }
    def year = @site.church.today.year
  end

  class NavLink < Liquid::Drop
    def initialize(title, url, current) = (@title, @url, @current = title, url, current)
    def title = @title
    def url = @url
    def current = @current
  end

  class Church < Liquid::Drop
    def initialize(church) = @church = church
    def name = @church.name
    def contact_email = @church.contact_email.to_s
    def giving_url = @church.giving_url.to_s
    def mailing_address = @church.mailing_address.to_s
  end

  class Page < Liquid::Drop
    def initialize(page) = @page = page
    def title = @page&.title.to_s
    def url = @page&.path.to_s
    def seo_title = @page&.seo_title.presence || title
    def seo_description = @page&.seo_description.to_s
  end

  class Group < Liquid::Drop
    def initialize(group, join_url) = (@group, @join_url = group, join_url)
    def name = @group.name
    def description = @group.description.to_s
    def type = @group.group_type.humanize
    def type_key = @group.group_type
    def meets = @group.meeting_summary
    def area = [ @group.city, @group.region ].compact_blank.join(", ")
    def full = @group.full?
    def join_url = @join_url
  end

  class ServiceTime < Liquid::Drop
    def initialize(service) = @service = service
    def name = @service.name
    def day = Date::DAYNAMES[@service.day_of_week]
    def time = @service.start_time.strftime("%-l:%M %p")
    def campus = @service.campus&.name.to_s
  end

  class Campus < Liquid::Drop
    def initialize(campus) = @campus = campus
    def name = @campus.name
    def address = [ @campus.try(:address_line1), [ @campus.try(:city), @campus.try(:region), @campus.try(:postal_code) ].compact_blank.join(", ") ].compact_blank.join("\n")
    def map_url = address.present? ? "https://www.openstreetmap.org/search?query=#{ERB::Util.url_encode(address.tr("\n", " "))}" : ""
  end

  class Form < Liquid::Drop
    def initialize(form, html) = (@form, @html = form, html)
    def name = @form.name
    def description = @form.description.to_s
    def url = "/f/#{@form.slug}"
    def html = @html.call # rendered on use, with the spam protections of the public form
  end
end

# forms["connect"] → a Form drop, or nothing (a missing or unpublished form never breaks the page).
class Site::Drops::Forms < Liquid::Drop
  def initialize(forms) = @forms = forms
  def liquid_method_missing(slug) = @forms[slug.to_s]
end

require "rails_helper"

RSpec.describe "Church websites" do
  let!(:site) { Site.current }
  let(:site_host) { "#{church.subdomain}.sites.localhost" }

  def publish_everything
    site.update!(published: true)
    site.pages.each(&:publish!)
  end

  describe "visitors" do
    it "see nothing until the site is live, then only published pages" do
      host! site_host
      get "/"
      expect(response).to have_http_status(:not_found)

      site.update!(published: true)
      site.home_page.publish!
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Welcome home", "site-modern")
      get "/about"
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("We couldn&#39;t find that page").or include("We couldn't find that page")
    end

    it "see the published version while staff edit the draft, and the new one after publishing" do
      publish_everything
      about = site.pages.find_by!(slug: "about")
      entry = about.add_section!("call_to_action")
      about.update_section!(entry["id"], entry["settings"].merge("heading" => "Brand new draft heading"))
      host! site_host
      get "/about"
      expect(response.body).not_to include("Brand new draft heading")
      about.publish!
      get "/about"
      expect(response.body).to include("Brand new draft heading")
    end

    it "serve verified custom domains only" do
      publish_everything
      domain = create(:site_domain, site:, hostname: "www.gracechurch.org")
      host! "www.gracechurch.org"
      get "/"
      expect(response).to have_http_status(:not_found)
      domain.update!(status: "verified")
      get "/"
      expect(response.body).to include("Welcome home")
    end

    it "share nothing with the admin app: no sessions, and no admin pages on the site's host" do
      publish_everything
      host! site_host
      get "/"
      expect(response.headers["Set-Cookie"].to_s).not_to include("session")
      get "/session/new"
      expect(response).to have_http_status(:not_found)
      get "/people"
      expect(response).to have_http_status(:not_found)
    end

    it "submit embedded forms to the site's own domain" do
      Form::Starters.install!
      form = Form.find_by!(slug: "connect")
      form.publish!
      publish_everything
      host! site_host
      get "/contact"
      expect(response.body).to include('action="/f/connect"')
      get "/f/connect"
      expect(response).to have_http_status(:ok)
    end

    it "get a sitemap and robots.txt" do
      publish_everything
      host! site_host
      get "/sitemap.xml"
      expect(response.body).to include("<loc>http://#{site_host}/about</loc>")
      get "/robots.txt"
      expect(response.body).to include("Sitemap: http://#{site_host}/sitemap.xml")
    end

    it "see changes to events and groups without anyone republishing" do
      publish_everything
      host! site_host
      get "/groups"
      expect(response.body).not_to include("Thursday Moms")
      create(:group, name: "Thursday Moms")
      get "/groups"
      expect(response.body).to include("Thursday Moms")
    end
  end

  describe "the TLS proxy's question" do
    it "allows our hosts and verified domains, and nothing else" do
      create(:site_domain, :verified, site:, hostname: "www.gracechurch.org")
      create(:site_domain, site:, hostname: "www.pending.org")
      allowed = ->(domain) { get "/internal/tls/allowed", params: { domain: }; response.status }
      expect(allowed.("www.gracechurch.org")).to eq(200)
      expect(allowed.(site_host)).to eq(200)
      expect(allowed.(church.host)).to eq(200)
      expect(allowed.("www.pending.org")).to eq(404)
      expect(allowed.("random.example.com")).to eq(404)
      expect(allowed.("nobody.sites.localhost")).to eq(404)
    end

    it "requires the shared token when one is configured" do
      allow(Rails.configuration.x).to receive(:tls_ask_token).and_return("s3cret")
      get "/internal/tls/allowed", params: { domain: church.host }
      expect(response).to have_http_status(:forbidden)
      get "/internal/tls/allowed", params: { domain: church.host, token: "s3cret" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "staff" do
    let(:staff) { create(:user, :staff) }

    before { sign_in_as(staff) }

    it "build a page: add, edit, reorder, preview, and publish" do
      post website_pages_path, params: { page: { title: "Ministries", slug: "Ministries", show_in_nav: "1" } }
      page = site.pages.find_by!(slug: "ministries")
      post website_page_sections_path(page), params: { key: "text" }
      post website_page_sections_path(page), params: { key: "video" }
      text, video = page.reload.section_list
      patch website_page_section_path(page, text["id"]), params: { settings: { heading: "Our ministries", body: "**Kids**, youth, and more", align: "left" } }
      patch website_page_section_path(page, video["id"]), params: { settings: { heading: "Watch", url: "https://youtu.be/dQw4w9WgXcQ" } }
      patch move_website_page_section_path(page, video["id"]), params: { position: 0 }
      expect(page.reload.section_list.map { |s| s["key"] }).to eq(%w[ video text ])

      site.pages.find_by!(slug: "about").publish! # the menu lists published pages
      get preview_website_page_path(page, width: "mobile")
      expect(response.body).to include("Our ministries", "youtube-nocookie.com/embed/dQw4w9WgXcQ", "width: 390px")

      # Links in the preview go to the editor (site pages) or the real site (everything else), never the admin app's root.
      preview = Nokogiri::HTML5(CGI.unescapeHTML(Nokogiri::HTML5(response.body).at_css("iframe")["srcdoc"]))
      about = preview.at_css("a[href='#{website_page_path(site.pages.find_by!(slug: "about"))}']")
      expect(about["target"]).to eq("_top")
      expect(preview.css("a").map { |a| a["href"] }).not_to include("/about", "/")
      patch publish_website_page_path(page)
      expect(page.reload).to be_published
      get website_page_revisions_path(page)
      expect(response.body).to include("Restore as draft")
    end

    it "change the theme and its settings" do
      patch website_theme_path, params: { site: { theme_key: "classic" }, settings: { brand_color: "#112233", heading_font: "serif", tagline: "Love God, love people" } }
      expect(site.reload).to have_attributes(theme_key: "classic")
      expect(site.settings).to include("brand_color" => "#112233", "tagline" => "Love God, love people")
    end

    it "can't edit code or domains" do
      get website_sections_path
      expect(response).to have_http_status(:forbidden)
      post website_domains_path, params: { site_domain: { hostname: "www.x.org" } }
      expect(response).to have_http_status(:forbidden)
      get website_path
      expect(response.body).to include("A church admin can connect your own domain")
    end
  end

  describe "church admins (advanced mode)" do
    before { sign_in_as(create(:user, :church_admin)) }

    it "edit a built-in section's Liquid, get errors for bad Liquid, and reset it" do
      get website_sections_path
      expect(response.body).to include("Call to action", "Built-in")
      definition = SectionDefinition.kind_web.find_by!(key: "call_to_action")
      patch website_section_path(definition), params: { section_definition: { name: "CTA", liquid: "<section>{% if %}</section>", schema_json: definition.schema.except("version").to_json } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Liquid has an error")

      patch website_section_path(definition), params: { section_definition: { name: "CTA", liquid: "<section class=\"cta\">{{ settings.heading | escape }}!</section>", schema_json: definition.schema.except("version").to_json } }
      expect(definition.reload).to have_attributes(customized: true, liquid: include("cta"))
      SectionDefinition::Defaults.install!("web") # a later update doesn't overwrite the church's copy
      expect(definition.reload.liquid).to include("cta")

      post reset_website_section_path(definition)
      expect(definition.reload).to have_attributes(customized: false, liquid: SectionDefinition::Defaults.original_liquid("web", "call_to_action"))
    end

    it "create a custom section, which pages can then use" do
      post website_sections_path, params: { section_definition: { name: "Verse", key: "verse", liquid: "<blockquote>{{ settings.text | escape }}</blockquote>",
        schema_json: { settings: [ { id: "text", type: "text", label: "Verse", default: "Be still" } ] }.to_json } }
      expect(SectionDefinition.kind_web.find_by!(key: "verse")).not_to be_system
      page = site.home_page
      post website_page_sections_path(page), params: { key: "verse" }
      get preview_website_page_path(page)
      expect(response.body).to include("&lt;blockquote&gt;Be still").or include("Be still")

      post website_sections_path, params: { section_definition: { name: "Bad", key: "bad", liquid: "x", schema_json: "{not json" } }
      expect(response.body).to include("isn&#39;t valid JSON").or include("isn't valid JSON")
    end

    it "edit the layout, which must keep head and content_for_layout" do
      patch website_layout_path, params: { site: { layout_liquid: "<html><body>no content</body></html>" } }
      expect(flash[:alert]).to include("content_for_layout")
      patch website_layout_path, params: { site: { layout_liquid: "<html><head>{{ head }}</head><body class=\"mine\">{{ content_for_layout }}</body></html>" } }
      expect(site.reload.layout).to include("mine")
      delete website_layout_path
      expect(site.reload).not_to be_custom_layout
    end

    it "connect a domain and check it" do
      post website_domains_path, params: { site_domain: { hostname: "https://WWW.GraceChurch.org/" } }
      domain = SiteDomain.last
      expect(domain).to have_attributes(hostname: "www.gracechurch.org", status: "pending")
      allow_any_instance_of(Site::DnsCheck).to receive(:call).and_return(Site::DnsCheck::Result.new(true, "CNAME points to domains.sites.localhost"))
      post check_website_domain_path(domain)
      expect(domain.reload).to have_attributes(status: "verified", primary: true)
      expect(site.reload.host).to eq("www.gracechurch.org")
    end
  end
end

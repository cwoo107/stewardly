# Facebook Pages and Instagram business accounts, through Meta's Graph API.
#
# TODO(verify vendor docs): this adapter is written from my understanding of the Graph API
# (pinned to META_GRAPH_VERSION, default v21.0) and has NOT been checked against Meta's
# current documentation. Before enabling it in production, verify each call marked below,
# and turn the pending examples in spec/models/social/providers/meta_spec.rb into real ones:
#   - OAuth dialog, code exchange, long-lived token exchange
#   - GET /me/accounts fields (page token, picture, linked instagram_business_account)
#   - Page posts: POST /{page}/feed (message, link) and photos (POST /{page}/photos,
#     unpublished uploads attached with attached_media)
#   - Instagram: POST /{ig}/media (image_url, caption; carousel children), POST /{ig}/media_publish
#   - permalinks, /debug_token, and error codes (190 = token invalid; is_transient)
#
# The app ID and secret are the platform's own (META_APP_ID, META_APP_SECRET): one Meta
# app, which each church authorizes for its own Pages.
class Social::Providers::Meta < Social::Provider
  SCOPES = %w[ pages_show_list pages_read_engagement pages_manage_posts instagram_basic instagram_content_publish business_management ].freeze
  TRANSIENT_CODES = [ 1, 2, 4, 17, 32, 341, 368, 613 ].freeze

  LIMITS = {
    "facebook_page" => Limits.new(caption_length: 63_206, max_photos: 10, photo_required: false, links_clickable: true),
    "instagram" => Limits.new(caption_length: 2_200, max_photos: 10, photo_required: true, links_clickable: false)
  }.freeze

  def self.version = ENV.fetch("META_GRAPH_VERSION", "v21.0")
  def self.app_id = ENV["META_APP_ID"]
  def self.app_secret = ENV["META_APP_SECRET"]
  def self.configured? = app_id.present? && app_secret.present?
  def self.limits(network) = LIMITS.fetch(network)

  # TODO(verify vendor docs): the OAuth dialog URL and parameters.
  def self.authorize_url(state:, redirect_uri:)
    query = { client_id: app_id, redirect_uri:, state:, scope: SCOPES.join(","), response_type: "code" }.to_query
    "https://www.facebook.com/#{version}/dialog/oauth?#{query}"
  end

  # TODO(verify vendor docs): code → short-lived token → long-lived token; /me; /me/accounts fields.
  def self.connect(code:, redirect_uri:)
    short = graph_get("oauth/access_token", client_id: app_id, client_secret: app_secret, redirect_uri:, code:)
    long = graph_get("oauth/access_token", grant_type: "fb_exchange_token", client_id: app_id, client_secret: app_secret,
      fb_exchange_token: short.fetch("access_token"))
    user_token = long.fetch("access_token")
    expires_at = long["expires_in"] && Time.current + long["expires_in"].to_i
    me = graph_get("me", access_token: user_token, fields: "id,name")
    pages = graph_get("me/accounts", access_token: user_token,
      fields: "id,name,access_token,picture{url},instagram_business_account{id,username,profile_picture_url}")

    accounts = Array(pages["data"]).flat_map do |page|
      facebook = AccountRecord.new("facebook_page", page["id"], page["name"], nil, page.dig("picture", "data", "url"), page["access_token"], nil)
      instagram = page["instagram_business_account"]&.then do |ig|
        # Instagram posts are made with the linked Page's token.
        AccountRecord.new("instagram", ig["id"], ig["username"] || page["name"], ig["username"], ig["profile_picture_url"], page["access_token"], nil)
      end
      [ facebook, instagram ].compact
    end
    [ user_token, expires_at, me["id"], accounts ]
  end

  def initialize(integration)
    @integration = integration
  end

  def publish(target, photo_urls:)
    account = target.social_account
    account.instagram? ? publish_instagram(account, target, photo_urls) : publish_facebook(account, target, photo_urls)
  end

  # TODO(verify vendor docs): /debug_token with an app access token.
  def validate(account)
    data = self.class.graph_get("debug_token", input_token: account.access_token, access_token: "#{self.class.app_id}|#{self.class.app_secret}")
    raise Error.new("Meta says this connection is no longer valid", reconnect: true) unless data.dig("data", "is_valid")
  end

  private
    # TODO(verify vendor docs): Page feed and photo publishing, and permalink_url.
    def publish_facebook(account, target, photo_urls)
      token = account.access_token
      text = [ target.caption_text, (target.social_post.link_url if photo_urls.any?) ].compact_blank.join("\n\n")
      post_id =
        if photo_urls.one?
          self.class.graph_post("#{account.external_id}/photos", access_token: token, url: photo_urls.first, caption: text, published: true)["post_id"]
        elsif photo_urls.many?
          ids = photo_urls.map { |url| self.class.graph_post("#{account.external_id}/photos", access_token: token, url:, published: false).fetch("id") }
          attached = ids.each_with_index.to_h { |id, index| [ "attached_media[#{index}]", { media_fbid: id }.to_json ] }
          self.class.graph_post("#{account.external_id}/feed", access_token: token, message: text, **attached.symbolize_keys).fetch("id")
        else
          self.class.graph_post("#{account.external_id}/feed", access_token: token, message: target.caption_text, link: target.social_post.link_url.presence).fetch("id")
        end
      permalink = self.class.graph_get(post_id, access_token: token, fields: "permalink_url")["permalink_url"] rescue nil
      PublishResult.new(external_post_id: post_id, permalink:)
    end

    # TODO(verify vendor docs): the two-step container → media_publish flow, carousels, and permalink.
    def publish_instagram(account, target, photo_urls)
      token = account.access_token
      raise Error.new("Instagram posts need at least one photo") if photo_urls.empty?

      caption = [ target.caption_text, (target.social_post.link_url.present? ? "Link in bio: #{target.social_post.link_url}" : nil) ].compact_blank.join("\n\n")
      container =
        if photo_urls.one?
          self.class.graph_post("#{account.external_id}/media", access_token: token, image_url: photo_urls.first, caption:).fetch("id")
        else
          children = photo_urls.map { |url| self.class.graph_post("#{account.external_id}/media", access_token: token, image_url: url, is_carousel_item: true).fetch("id") }
          self.class.graph_post("#{account.external_id}/media", access_token: token, media_type: "CAROUSEL", children: children.join(","), caption:).fetch("id")
        end
      media_id = self.class.graph_post("#{account.external_id}/media_publish", access_token: token, creation_id: container).fetch("id")
      permalink = self.class.graph_get(media_id, access_token: token, fields: "permalink")["permalink"] rescue nil
      PublishResult.new(external_post_id: media_id, permalink:)
    end

    class << self
      def graph_get(path, **params) = request(Net::HTTP::Get.new(uri(path, params)))

      def graph_post(path, **params)
        request = Net::HTTP::Post.new(uri(path, {}))
        request.set_form_data(params.compact.transform_values(&:to_s))
        request(request)
      end

      private
        def uri(path, params)
          URI("https://graph.facebook.com/#{version}/#{path}").tap { |u| u.query = params.compact.to_query if params.any? }
        end

        # TODO(verify vendor docs): error payload { error: { message, code, is_transient } }.
        def request(request)
          response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: true, open_timeout: 5, read_timeout: 30) { |http| http.request(request) }
          body = JSON.parse(response.body.presence || "{}")
          return body if response.is_a?(Net::HTTPSuccess)

          error = body["error"].to_h
          raise Social::Provider::Error.new(error["message"].presence || "Meta returned HTTP #{response.code}",
            transient: error["is_transient"] == true || Social::Providers::Meta::TRANSIENT_CODES.include?(error["code"]) || response.code.to_i >= 500,
            reconnect: error["code"] == 190)
        rescue JSON::ParserError, SocketError, IOError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => error
          raise Social::Provider::Error.new("Couldn't reach Meta (#{error.class})", transient: true)
        end
    end
end

# Development only (bin/demo). People viewing through a demo tunnel never see developer
# tools: detailed error pages (source code, parameters), mail previews, or /rails/info
# (routes and settings), which development otherwise shows to anyone. Active Storage
# (/rails/active_storage, i.e. images) still works.
class DemoTunnelGuard
  DEVELOPER_PATHS = %r{\A/rails/(?!active_storage/)}

  def initialize(app) = @app = app

  def call(env)
    hosts = [ ENV["DEMO_APP_HOST"], ENV["DEMO_SITE_HOST"] ].compact_blank
    return @app.call(env) unless hosts.include?(env["HTTP_HOST"].to_s.split(":").first.to_s.downcase)

    return [ 404, { "content-type" => "text/plain" }, [ "Not found\n" ] ] if env["PATH_INFO"].to_s.match?(DEVELOPER_PATHS)

    env["action_dispatch.show_detailed_exceptions"] = false
    @app.call(env)
  end
end

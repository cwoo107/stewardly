# Sidekiq uses REDIS_URL, a Redis instance that must run with
# maxmemory-policy noeviction. The cache has its own Redis (REDIS_CACHE_URL,
# allkeys-lru) so cache pressure can never evict queued jobs.
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }

Sidekiq.configure_server do |config|
  config.redis = redis_config

  # Recurring jobs live in config/schedule.yml.
  config.on(:startup) do
    schedule = Rails.root.join("config/schedule.yml")
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(schedule)) if schedule.exist?
  end
end

Sidekiq.configure_client { |config| config.redis = redis_config }

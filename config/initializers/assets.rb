# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w[ admin.js admin.css ]

# Sprockets writes assets in parallel threads; on Windows two threads writing the same
# .gz file collide on rename (Errno::EACCES), so export sequentially there.
Rails.application.config.assets.export_concurrent = false if Gem.win_platform?

# The file-backed Sprockets cache hits the same rename collision on Windows
# (tmp/cache/assets/*.cache), so keep the cache in memory there instead.
if Gem.win_platform?
  Rails.application.config.assets.configure do |env|
    env.cache = Sprockets::Cache::MemoryStore.new(10_000)
  end
end

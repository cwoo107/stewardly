# cache_version is an Active Record method name.
class RenameSitesCacheVersion < ActiveRecord::Migration[8.1]
  def change
    rename_column :sites, :cache_version, :content_version
  end
end

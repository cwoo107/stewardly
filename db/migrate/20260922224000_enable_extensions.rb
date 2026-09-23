class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "postgis"
    # Case-insensitive emails and subdomains
    enable_extension "citext"
  end
end

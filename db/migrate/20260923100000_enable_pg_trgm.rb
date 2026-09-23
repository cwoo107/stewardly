class EnablePgTrgm < ActiveRecord::Migration[8.1]
  def change
    # Trigram indexes make ILIKE '%term%' people search fast
    enable_extension "pg_trgm"
  end
end

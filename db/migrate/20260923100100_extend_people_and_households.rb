class ExtendPeopleAndHouseholds < ActiveRecord::Migration[8.1]
  def change
    change_table :people, bulk: true do |t|
      t.jsonb :custom_fields, null: false, default: {}
      # Set when this record was folded into another by a merge; merged people are hidden everywhere
      t.references :merged_into, foreign_key: { to_table: :people }
      t.datetime :merged_at
    end
    add_index :people, :custom_fields, using: :gin
    add_index :people, "(first_name || ' ' || last_name) gin_trgm_ops", using: :gin, name: "index_people_on_full_name_trgm"
    add_index :people, "email gin_trgm_ops", using: :gin, name: "index_people_on_email_trgm"
    add_index :people, "phone gin_trgm_ops", using: :gin, name: "index_people_on_phone_trgm"

    change_table :households, bulk: true do |t|
      t.datetime :geocoded_at
      t.string :geocode_error
    end

    change_table :churches, bulk: true do |t|
      t.integer :group_coverage_miles, null: false, default: 3
    end
  end
end

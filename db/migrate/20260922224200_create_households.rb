class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.references :church, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country, null: false, default: "US"
      # geography: true distances in meters on lat/lng, supports ST_DWithin and KNN (<->)
      t.st_point :location, geographic: true, srid: 4326

      t.timestamps
    end
    add_index :households, :location, using: :gist
  end
end

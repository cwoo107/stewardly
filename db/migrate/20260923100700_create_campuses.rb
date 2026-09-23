class CreateCampuses < ActiveRecord::Migration[8.1]
  def change
    create_table :campuses do |t|
      t.references :church, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :is_default, null: false, default: false
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country, null: false, default: "US"
      t.st_point :location, geographic: true, srid: 4326
      t.datetime :geocoded_at
      t.string :geocode_error

      t.timestamps
    end
    add_index :campuses, :location, using: :gist
    add_index :campuses, :church_id, unique: true, where: "is_default", name: "index_campuses_one_default_per_church"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO campuses (church_id, name, is_default, country, created_at, updated_at)
          SELECT id, 'Main campus', true, 'US', now(), now() FROM churches
        SQL
      end
    end
  end
end

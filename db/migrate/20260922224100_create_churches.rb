class CreateChurches < ActiveRecord::Migration[8.1]
  def change
    create_table :churches do |t|
      t.string :name, null: false
      t.citext :subdomain, null: false
      t.string :time_zone, null: false

      t.timestamps
    end
    add_index :churches, :subdomain, unique: true
  end
end

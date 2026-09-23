class CreateAttendance < ActiveRecord::Migration[8.1]
  def change
    create_table :attendance_counts do |t|
      t.references :church, null: false, foreign_key: true
      t.references :service_occurrence, null: false, foreign_key: true, index: { unique: true }
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.integer :total, null: false
      t.jsonb :breakdown, null: false, default: {} # { "Adults" => 210, "Kids" => 64, "Online" => 90 }
      t.integer :first_time_guests, null: false, default: 0
      t.text :note

      t.timestamps
    end

    create_table :attendances do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :service_occurrence, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.references :checked_in_by, foreign_key: { to_table: :users }
      t.datetime :checked_in_at, null: false
      t.boolean :first_time, null: false, default: false

      t.timestamps
    end
    add_index :attendances, [ :service_occurrence_id, :person_id ], unique: true
    add_index :attendances, [ :church_id, :person_id, :checked_in_at ]

    create_table :special_sundays do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.date :local_date, null: false
      t.string :name, null: false
      t.string :key, null: false # same kind of day across years, e.g. "back-to-school"
      t.integer :expected_change_percent

      t.timestamps
    end
    add_index :special_sundays, [ :church_id, :local_date ], unique: true
    add_index :special_sundays, [ :church_id, :key ]

    create_table :attendance_forecasts do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :service_occurrence, null: false, foreign_key: true, index: { unique: true }
      t.integer :expected, null: false
      t.integer :low, null: false
      t.integer :high, null: false
      t.integer :expected_online
      t.jsonb :factors, null: false, default: []
      t.string :model_version, null: false
      t.datetime :generated_at, null: false
      t.datetime :frozen_at

      t.timestamps
    end
    add_index :attendance_forecasts, [ :church_id, :generated_at ]

    add_column :churches, :attendance_categories, :string, array: true, null: false, default: %w[ Adults Kids Online ]
  end
end

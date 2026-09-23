class CreateScheduling < ActiveRecord::Migration[8.1]
  def change
    create_table :worship_services do |t|
      t.references :church, null: false, foreign_key: true
      t.references :campus, foreign_key: true
      t.string :name, null: false
      t.integer :day_of_week, null: false, default: 0 # 0 = Sunday, like Date#wday
      t.time :start_time, null: false
      t.integer :duration_minutes, null: false, default: 75
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :service_occurrences do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :worship_service, null: false, foreign_key: true, index: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.date :local_date, null: false # in the church's time zone
      t.boolean :cancelled, null: false, default: false

      t.timestamps
    end
    add_index :service_occurrences, [ :worship_service_id, :local_date ], unique: true
    add_index :service_occurrences, [ :church_id, :local_date ]

    create_table :position_needs do |t|
      t.references :church, null: false, foreign_key: true
      t.references :needable, polymorphic: true, null: false, index: false # WorshipService or Event
      t.references :position, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end
    add_index :position_needs, [ :needable_type, :needable_id, :position_id ], unique: true, name: "index_position_needs_uniqueness"

    create_table :assignments do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :schedulable, polymorphic: true, null: false, index: false # ServiceOccurrence or EventOccurrence
      t.references :position, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :assigned_by, foreign_key: { to_table: :users }
      t.date :local_date, null: false # copied from the occurrence, for same-day conflict checks
      t.string :status, null: false, default: "pending"
      t.string :response_token, null: false
      t.datetime :requested_at
      t.datetime :responded_at
      t.datetime :reminded_at
      t.text :note

      t.timestamps
    end
    add_index :assignments, [ :schedulable_type, :schedulable_id, :position_id, :person_id ], unique: true, name: "index_assignments_uniqueness"
    add_index :assignments, [ :church_id, :person_id, :local_date ]
    add_index :assignments, :response_token, unique: true

    create_table :position_qualifications do |t|
      t.references :church, null: false, foreign_key: true
      t.references :position, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true

      t.timestamps
    end
    add_index :position_qualifications, [ :position_id, :person_id ], unique: true

    create_table :blockouts do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true, index: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :reason

      t.timestamps
    end
    add_index :blockouts, [ :church_id, :person_id, :starts_on ]

    add_column :team_memberships, :max_per_month, :integer
  end
end

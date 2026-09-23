class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :ministry, foreign_key: true
      t.references :campus, foreign_key: true
      t.references :organizer, foreign_key: { to_table: :users }
      t.references :registration_form, foreign_key: { to_table: :forms }
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.string :location_name
      t.string :address_line1
      t.string :city
      t.string :region
      t.string :postal_code
      t.integer :capacity
      t.boolean :registration_required, null: false, default: false
      t.datetime :registration_opens_at
      t.datetime :registration_closes_at
      t.integer :max_party_size, null: false, default: 1
      t.string :visibility, null: false, default: "public"
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
    add_index :events, [ :church_id, :slug ], unique: true

    create_table :event_occurrences do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :event, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.date :local_date, null: false
      t.integer :capacity # overrides the event's
      t.boolean :cancelled, null: false, default: false
      t.datetime :reminders_sent_at

      t.timestamps
    end
    add_index :event_occurrences, [ :church_id, :local_date ]

    create_table :registrations do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :event_occurrence, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.references :form_submission, foreign_key: true
      t.integer :party_size, null: false, default: 1
      t.string :status, null: false, default: "confirmed"
      t.string :manage_token, null: false
      t.datetime :checked_in_at
      t.datetime :cancelled_at
      t.datetime :promoted_at

      t.timestamps
    end
    add_index :registrations, [ :event_occurrence_id, :status, :created_at ]
    add_index :registrations, [ :event_occurrence_id, :person_id ], unique: true, where: "status <> 'cancelled'",
      name: "index_registrations_one_active_per_person"
    add_index :registrations, :manage_token, unique: true

    add_column :forms, :access, :string, null: false, default: "public"
  end
end

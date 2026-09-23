class CreatePrayerRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :prayer_requests do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :person, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :requester_name
      t.string :requester_email
      t.text :body, null: false # encrypted
      t.string :visibility, null: false, default: "pastoral_staff"
      t.string :status, null: false, default: "active"
      t.string :source, null: false, default: "staff"
      t.datetime :answered_at
      t.text :answer_note # encrypted

      t.timestamps
    end
    add_index :prayer_requests, [ :church_id, :status, :created_at ]

    create_table :prayer_assignments do |t|
      t.references :church, null: false, foreign_key: true
      t.references :prayer_request, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :prayer_assignments, [ :prayer_request_id, :user_id ], unique: true
  end
end

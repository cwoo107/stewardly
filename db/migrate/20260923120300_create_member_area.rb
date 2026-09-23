class CreateMemberArea < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :author, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :published_at
      t.date :expires_on
      t.boolean :pinned, null: false, default: false

      t.timestamps
    end
    add_index :announcements, [ :church_id, :published_at ]

    create_table :group_join_requests do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :group, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.references :decided_by, foreign_key: { to_table: :users }
      t.text :message
      t.string :status, null: false, default: "pending"
      t.datetime :decided_at

      t.timestamps
    end
    add_index :group_join_requests, [ :group_id, :status ]
    add_index :group_join_requests, [ :group_id, :person_id ], unique: true, where: "status = 'pending'",
      name: "index_group_join_requests_one_pending"
    add_index :group_join_requests, [ :church_id, :status ]

    change_table :churches, bulk: true do |t|
      t.string :contact_email
      t.string :giving_url
      t.integer :reminder_days_before, null: false, default: 3
    end
  end
end

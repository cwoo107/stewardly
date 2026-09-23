class CreateInsightsAndReports < ActiveRecord::Migration[8.1]
  def change
    create_table :insights do |t|
      t.references :church, null: false, foreign_key: true
      t.string :kind, null: false
      t.references :subject, polymorphic: true
      t.references :person, foreign_key: true
      t.string :severity, null: false, default: "medium"
      t.string :title, null: false
      t.text :detail
      t.jsonb :data, null: false, default: {}
      t.string :action_label
      t.string :action_path
      t.string :audience_permission, null: false
      t.bigint :audience_user_ids, array: true, null: false, default: [] # people it belongs to directly (task owner, team leaders)
      t.string :fingerprint, null: false
      t.string :status, null: false, default: "open"
      t.date :snoozed_until
      t.string :resolution
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.references :task, foreign_key: true
      t.datetime :detected_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :insights, %i[ church_id fingerprint ], unique: true, where: "status IN ('open', 'snoozed')", name: "index_insights_one_live_per_fingerprint"
    add_index :insights, %i[ church_id status severity ]
    add_index :insights, :audience_user_ids, using: :gin

    create_table :daily_briefs do |t|
      t.references :church, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.jsonb :items, null: false, default: []
      t.text :summary
      t.string :source, null: false, default: "rules"
      t.references :ai_request, foreign_key: true
      t.datetime :emailed_at
      t.timestamps
    end
    add_index :daily_briefs, %i[ user_id date ], unique: true

    create_table :report_conversations do |t|
      t.references :church, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.timestamps
    end
    add_index :report_conversations, %i[ church_id user_id updated_at ]

    create_table :report_messages do |t|
      t.references :church, null: false, foreign_key: true
      t.references :report_conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.string :status, null: false, default: "done" # pending while the assistant is answering
      t.jsonb :tool_calls, null: false, default: []
      t.jsonb :unverified_figures, null: false, default: []
      t.text :error
      t.references :ai_request, foreign_key: true
      t.timestamps
    end

    create_table :saved_reports do |t|
      t.references :church, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :question
      t.text :summary
      t.jsonb :tool_calls, null: false, default: []
      t.jsonb :last_result, null: false, default: []
      t.datetime :last_run_at
      t.boolean :pinned, null: false, default: false
      t.timestamps
    end
    add_index :saved_reports, %i[ church_id user_id pinned ]

    add_column :users, :brief_email, :boolean, null: false, default: false
    add_column :churches, :no_contact_days, :integer, null: false, default: 60
    add_column :churches, :ai_private_totals, :boolean, null: false, default: false
  end
end

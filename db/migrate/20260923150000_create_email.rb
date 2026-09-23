class CreateEmail < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :category, null: false # email_delivery, email_audience_sync (giving later)
      t.string :provider, null: false # postmark, ses, mailchimp
      t.text :credentials # encrypted JSON
      t.jsonb :settings, null: false, default: {}
      t.string :status, null: false, default: "active"
      t.string :webhook_token, null: false

      t.timestamps
    end
    add_index :integrations, [ :church_id, :category ], unique: true, where: "status = 'active'", name: "index_integrations_one_active_per_category"
    add_index :integrations, :webhook_token, unique: true

    create_table :webhook_events do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :integration, null: false, foreign_key: true
      t.string :provider, null: false
      t.text :raw_body, null: false
      t.jsonb :headers, null: false, default: {}
      t.string :status, null: false, default: "received"
      t.text :error
      t.datetime :processed_at

      t.timestamps
    end
    add_index :webhook_events, [ :church_id, :created_at ]

    create_table :section_definitions do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :kind, null: false, default: "email" # email now, web in Phase 10
      t.string :key, null: false
      t.string :name, null: false
      t.text :liquid, null: false
      t.jsonb :schema, null: false, default: {}
      t.boolean :system, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :section_definitions, [ :church_id, :kind, :key ], unique: true

    create_table :email_templates do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :subject
      t.string :preheader
      t.jsonb :theme, null: false, default: {}
      t.jsonb :sections, null: false, default: []

      t.timestamps
    end
    add_index :email_templates, [ :church_id, :name ]

    create_table :email_topics do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.text :description
      t.boolean :default_subscribed, null: false, default: true

      t.timestamps
    end
    add_index :email_topics, [ :church_id, :name ], unique: true

    create_table :email_preferences do |t|
      t.references :church, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true, index: false
      t.references :email_topic, null: false, foreign_key: true
      t.boolean :subscribed, null: false

      t.timestamps
    end
    add_index :email_preferences, [ :person_id, :email_topic_id ], unique: true

    create_table :campaigns do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :email_template, foreign_key: true
      t.references :segment, foreign_key: true
      t.references :email_topic, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :subject
      t.string :preheader
      t.string :from_name
      t.string :reply_to
      t.string :status, null: false, default: "draft"
      t.datetime :scheduled_at
      t.datetime :sending_at
      t.datetime :sent_at
      t.boolean :track_engagement, null: false, default: true
      t.text :html_snapshot

      t.timestamps
    end
    add_index :campaigns, [ :church_id, :status, :scheduled_at ]

    create_table :deliveries do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :campaign, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.string :email, null: false
      t.string :status, null: false, default: "queued"
      t.string :token, null: false
      t.string :provider_message_id
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :first_opened_at
      t.integer :open_count, null: false, default: 0
      t.datetime :first_clicked_at
      t.integer :click_count, null: false, default: 0
      t.datetime :unsubscribed_at
      t.text :error

      t.timestamps
    end
    add_index :deliveries, [ :campaign_id, :person_id ], unique: true
    add_index :deliveries, [ :campaign_id, :status ]
    add_index :deliveries, :token, unique: true
    add_index :deliveries, [ :church_id, :provider_message_id ]

    create_table :suppressions do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :email_topic, foreign_key: true
      t.citext :email, null: false
      t.string :reason, null: false # unsubscribed, hard_bounce, complaint, manual
      t.string :source
      t.text :note

      t.timestamps
    end
    add_index :suppressions, [ :church_id, :email ]
    add_index :suppressions, [ :church_id, :email, :email_topic_id ], unique: true, name: "index_suppressions_uniqueness", nulls_not_distinct: true

    change_table :churches, bulk: true do |t|
      t.text :mailing_address
      t.string :email_from_domain
    end
  end
end

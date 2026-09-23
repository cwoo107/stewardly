class CreateSocial < ActiveRecord::Migration[8.1]
  def change
    create_table :social_accounts do |t|
      t.references :church, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.string :network, null: false # facebook_page | instagram
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :handle
      t.string :avatar_url
      t.text :access_token # encrypted
      t.datetime :token_expires_at
      t.string :status, null: false, default: "connected"
      t.string :last_error
      t.datetime :checked_at
      t.timestamps
    end
    add_index :social_accounts, %i[ church_id network external_id ], unique: true

    create_table :social_posts do |t|
      t.references :church, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :event, foreign_key: true
      t.text :body, null: false, default: ""
      t.string :link_url
      t.string :status, null: false, default: "draft"
      t.string :source, null: false, default: "staff"
      t.datetime :scheduled_at
      t.datetime :published_at
      t.timestamps
    end
    add_index :social_posts, %i[ church_id status scheduled_at ]
    add_index :social_posts, %i[ church_id event_id ], unique: true, where: "source = 'event_promo'", name: "index_social_posts_one_promo_per_event"

    create_table :social_post_targets do |t|
      t.references :church, null: false, foreign_key: true
      t.references :social_post, null: false, foreign_key: true, index: false
      t.references :social_account, null: false, foreign_key: true
      t.text :caption # per-network override; blank uses the post's text
      t.string :status, null: false, default: "pending"
      t.string :external_post_id
      t.string :permalink
      t.text :error
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at
      t.datetime :published_at
      t.timestamps
    end
    add_index :social_post_targets, %i[ social_post_id social_account_id ], unique: true, name: "index_social_post_targets_uniqueness"
    add_index :social_post_targets, %i[ status next_attempt_at ]

    add_column :churches, :social_event_promos, :boolean, null: false, default: true
  end
end

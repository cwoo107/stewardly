class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.references :church, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :theme_key, null: false, default: "modern"
      t.jsonb :theme_settings, null: false, default: {}
      t.text :layout_liquid # nil: the theme's own layout
      t.integer :cache_version, null: false, default: 1
      t.boolean :published, null: false, default: false # the whole site is live
      t.datetime :published_at
      t.timestamps
    end

    create_table :site_domains do |t|
      t.references :church, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :hostname, null: false
      t.string :status, null: false, default: "pending"
      t.boolean :primary, null: false, default: false
      t.datetime :verified_at
      t.datetime :last_checked_at
      t.string :last_check_result
      t.timestamps
    end
    add_index :site_domains, :hostname, unique: true # across every church: one domain, one site

    create_table :pages do |t|
      t.references :church, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false, default: ""
      t.string :kind, null: false, default: "custom"
      t.jsonb :draft_sections, null: false, default: []
      t.jsonb :published_sections
      t.datetime :published_at
      t.datetime :draft_updated_at
      t.boolean :show_in_nav, null: false, default: true
      t.integer :position, null: false, default: 0
      t.string :seo_title
      t.text :seo_description
      t.timestamps
    end
    add_index :pages, %i[ site_id slug ], unique: true
    add_index :pages, %i[ site_id position ]

    create_table :page_revisions do |t|
      t.references :church, null: false, foreign_key: true
      t.references :page, null: false, foreign_key: true
      t.jsonb :sections, null: false, default: []
      t.references :published_by, foreign_key: { to_table: :users }
      t.datetime :published_at, null: false
      t.timestamps
    end

    add_column :section_definitions, :customized, :boolean, null: false, default: false
  end
end

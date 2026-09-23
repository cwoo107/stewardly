class CreateForms < ActiveRecord::Migration[8.1]
  def change
    create_table :forms do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.string :purpose, null: false, default: "general"
      t.text :confirmation_message
      t.datetime :published_at

      t.timestamps
    end
    add_index :forms, [ :church_id, :slug ], unique: true

    create_table :form_fields do |t|
      t.references :church, null: false, foreign_key: true
      t.references :form, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.string :label, null: false
      t.text :help_text
      t.string :field_type, null: false
      t.boolean :required, null: false, default: false
      t.string :options, array: true, null: false, default: []
      t.integer :position, null: false, default: 0
      # Where the answer goes on submission, e.g. "person.email", "household.address", "prayer_request.body"
      t.string :maps_to
      # Sensitive answers are stored encrypted, apart from the jsonb answers
      t.boolean :sensitive, null: false, default: false
      # { match: "all" | "any", conditions: [{ field:, operator:, value: }] }; empty = always shown
      t.jsonb :visibility_rule, null: false, default: {}

      t.timestamps
    end
    add_index :form_fields, [ :form_id, :key ], unique: true
    add_index :form_fields, [ :form_id, :position ]
    add_index :form_fields, [ :form_id, :maps_to ], unique: true, where: "maps_to IS NOT NULL"

    create_table :form_submissions do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :form, null: false, foreign_key: true, index: false
      t.references :person, foreign_key: true
      t.references :user, foreign_key: true
      t.jsonb :answers, null: false, default: {}
      t.text :sensitive_answers # encrypted JSON
      t.string :status, null: false, default: "received"
      t.datetime :processed_at
      t.string :ip_address

      t.timestamps
    end
    add_index :form_submissions, [ :form_id, :created_at ]
    add_index :form_submissions, [ :church_id, :status ]

    add_reference :prayer_requests, :form_submission, foreign_key: true
  end
end

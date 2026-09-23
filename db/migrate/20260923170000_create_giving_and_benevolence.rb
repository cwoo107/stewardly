class CreateGivingAndBenevolence < ActiveRecord::Migration[8.1]
  def change
    create_table :funds do |t|
      t.references :church, null: false, foreign_key: true
      t.string :name, null: false
      t.string :provider, null: false, default: "manual"
      t.string :external_id
      t.text :description
      t.boolean :active, null: false, default: true
      t.boolean :benevolence, null: false, default: false # offered when recording benevolence payments
      t.timestamps
    end
    add_index :funds, %i[ church_id provider external_id ], unique: true, where: "external_id IS NOT NULL"
    add_index :funds, %i[ church_id name ]

    create_table :donations do |t|
      t.references :church, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.references :fund, foreign_key: true
      t.string :provider, null: false
      t.string :external_id, null: false
      t.string :donor_external_id
      t.text :donor_name # encrypted
      t.text :donor_email # encrypted
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.date :given_on, null: false
      t.string :method
      t.string :status, null: false, default: "succeeded"
      t.string :match_status, null: false, default: "unmatched"
      t.references :matched_by, foreign_key: { to_table: :users }
      t.datetime :matched_at
      t.timestamps
    end
    add_index :donations, %i[ church_id provider external_id ], unique: true
    add_index :donations, %i[ church_id given_on ]
    add_index :donations, %i[ church_id match_status ]
    add_index :donations, %i[ church_id provider donor_external_id ]

    create_table :donor_links do |t|
      t.references :church, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :donor_external_id, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :donor_links, %i[ church_id provider donor_external_id ], unique: true

    create_table :giving_sync_runs do |t|
      t.references :church, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "running"
      t.date :window_start
      t.date :window_end
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :matched_count, null: false, default: 0
      t.integer :unmatched_count, null: false, default: 0
      t.text :error
      t.datetime :finished_at
      t.timestamps
    end
    add_index :giving_sync_runs, %i[ church_id created_at ]

    create_table :benevolence_cases do |t|
      t.references :church, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :household, foreign_key: true
      t.references :form_submission, foreign_key: true, index: { unique: true }
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :decided_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "submitted"
      t.string :source, null: false, default: "staff"
      t.string :need_category, null: false, default: "other"
      t.integer :requested_cents, null: false, default: 0
      t.integer :approved_cents
      t.string :currency, null: false, default: "USD"
      t.text :summary # encrypted
      t.text :circumstances # encrypted
      t.text :decision_note # encrypted
      t.datetime :decided_at
      t.datetime :fulfilled_at
      t.timestamps
    end
    add_index :benevolence_cases, %i[ church_id status ]
    add_index :benevolence_cases, %i[ church_id created_at ]

    create_table :benevolence_notes do |t|
      t.references :church, null: false, foreign_key: true
      t.references :benevolence_case, null: false, foreign_key: true
      t.references :author, foreign_key: { to_table: :users }
      t.text :body, null: false # encrypted
      t.timestamps
    end

    create_table :benevolence_approvals do |t|
      t.references :church, null: false, foreign_key: true
      t.references :benevolence_case, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.string :decision, null: false
      t.integer :amount_cents
      t.text :note # encrypted
      t.timestamps
    end
    add_index :benevolence_approvals, %i[ benevolence_case_id user_id ], unique: true

    create_table :benevolence_disbursements do |t|
      t.references :church, null: false, foreign_key: true
      t.references :benevolence_case, null: false, foreign_key: true
      t.references :fund, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.date :paid_on, null: false
      t.string :method, null: false
      t.string :payee_type, null: false
      t.string :payee_name, null: false
      t.text :reference # encrypted
      t.timestamps
    end
    add_index :benevolence_disbursements, %i[ church_id paid_on ]

    add_column :churches, :benevolence_approval_threshold_cents, :integer, null: false, default: 50_000
    add_column :churches, :benevolence_approvals_required, :integer, null: false, default: 1
    add_column :churches, :benevolence_annual_limit_cents, :integer, null: false, default: 100_000
    add_column :churches, :benevolence_limit_scope, :string, null: false, default: "household"
  end
end

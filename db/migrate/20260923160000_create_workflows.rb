class CreateWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows do |t|
      t.references :church, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.jsonb :draft_definition, null: false, default: {}
      t.bigint :current_version_id
      t.string :trigger_type # copied from the published version, to find workflows for an event quickly
      t.boolean :allow_reentry, null: false, default: false
      t.string :starter_key
      t.timestamps
    end
    add_index :workflows, %i[ church_id status trigger_type ]
    add_index :workflows, %i[ church_id starter_key ], unique: true, where: "starter_key IS NOT NULL"

    create_table :workflow_versions do |t|
      t.references :church, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.integer :number, null: false
      t.jsonb :definition, null: false, default: {}
      t.references :published_by, foreign_key: { to_table: :users }
      t.datetime :published_at, null: false
      t.timestamps
    end
    add_index :workflow_versions, %i[ workflow_id number ], unique: true
    add_foreign_key :workflows, :workflow_versions, column: :current_version_id

    create_table :workflow_runs do |t|
      t.references :church, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.references :workflow_version, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :trigger_subject, polymorphic: true
      t.string :status, null: false, default: "active"
      t.string :current_step_id
      t.datetime :wake_at
      t.boolean :allow_concurrent, null: false, default: false
      t.string :exit_reason
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
    add_index :workflow_runs, %i[ workflow_id person_id ], unique: true, name: "index_workflow_runs_one_in_flight",
      where: "status IN ('active', 'waiting') AND NOT allow_concurrent"
    add_index :workflow_runs, %i[ church_id workflow_id status ]
    add_index :workflow_runs, %i[ person_id started_at ]

    create_table :workflow_step_executions do |t|
      t.references :church, null: false, foreign_key: true
      t.references :workflow_run, null: false, foreign_key: true, index: false
      t.string :step_id, null: false
      t.string :step_type, null: false
      t.string :status, null: false, default: "running"
      t.jsonb :result, null: false, default: {}
      t.text :error
      t.datetime :executed_at
      t.timestamps
    end
    add_index :workflow_step_executions, %i[ workflow_run_id step_id ], unique: true

    create_table :ai_requests do |t|
      t.references :church, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :purpose, null: false
      t.string :provider, null: false
      t.string :model
      t.jsonb :prompt, null: false, default: {}
      t.jsonb :response, null: false, default: {}
      t.jsonb :tool_calls, null: false, default: []
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.text :error
      t.timestamps
    end
    add_index :ai_requests, %i[ church_id created_at ]

    create_table :message_drafts do |t|
      t.references :church, null: false, foreign_key: true
      t.references :workflow_step_execution, null: false, foreign_key: true, index: { unique: true }
      t.references :person, null: false, foreign_key: true
      t.references :email_template, foreign_key: true
      t.references :email_topic, foreign_key: true
      t.references :ai_request, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.text :body
      t.string :status, null: false, default: "pending"
      t.string :source, null: false, default: "ai"
      t.string :note
      t.boolean :auto_sent, null: false, default: false
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :message_drafts, %i[ church_id status created_at ]

    create_table :campaign_extra_recipients do |t|
      t.references :church, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.timestamps
    end
    add_index :campaign_extra_recipients, %i[ campaign_id person_id ], unique: true

    change_column_null :deliveries, :campaign_id, true
    add_reference :deliveries, :workflow_step_execution, foreign_key: true, index: { unique: true }
    add_reference :deliveries, :email_topic, foreign_key: true
    add_column :deliveries, :subject, :string
    add_column :deliveries, :html_snapshot, :text

    add_column :tasks, :workflow_step_execution_id, :bigint
    add_index :tasks, :workflow_step_execution_id, unique: true
    add_foreign_key :tasks, :workflow_step_executions

    add_column :churches, :ai_enabled, :boolean, null: false, default: false
    add_column :churches, :ai_monthly_token_cap, :integer, null: false, default: 200_000
    add_column :churches, :workflow_daily_send_limit, :integer, null: false, default: 500
  end
end

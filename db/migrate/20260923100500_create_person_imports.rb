class CreatePersonImports < ActiveRecord::Migration[8.1]
  def change
    create_table :person_imports do |t|
      t.references :church, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.jsonb :mapping, null: false, default: {}
      t.integer :row_count, null: false, default: 0
      t.integer :processed_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.jsonb :row_errors, null: false, default: []
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end

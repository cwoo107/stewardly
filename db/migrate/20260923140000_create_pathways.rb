class CreatePathways < ActiveRecord::Migration[8.1]
  def change
    create_table :pathways do |t|
      t.references :church, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false

      t.timestamps
    end

    create_table :pathway_stages do |t|
      t.references :church, null: false, foreign_key: true
      t.references :pathway, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.jsonb :definition, null: false, default: {} # segment-style { match, conditions }; the first stage has none
      t.integer :stuck_after_days
      t.text :description

      t.timestamps
    end
    add_index :pathway_stages, [ :pathway_id, :position ]

    create_table :pathway_placements do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.references :pathway_stage, null: false, foreign_key: true
      t.datetime :entered_at, null: false
      t.datetime :evaluated_at, null: false

      t.timestamps
    end
    add_index :pathway_placements, [ :church_id, :pathway_stage_id, :entered_at ]

    create_table :pathway_transitions do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.references :from_stage, foreign_key: { to_table: :pathway_stages }
      t.references :to_stage, null: false, foreign_key: { to_table: :pathway_stages }
      t.string :direction, null: false # forward, back, or placed (first placement)
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :pathway_transitions, [ :church_id, :occurred_at ]
    add_index :pathway_transitions, [ :person_id, :occurred_at ]

    add_column :churches, :volunteer_load_thresholds, :jsonb, null: false, default: {}
  end
end

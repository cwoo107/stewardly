class CreateProjectsAndTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :church, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.datetime :archived_at

      t.timestamps
    end

    create_table :tasks do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :project, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :notes
      t.string :status, null: false, default: "todo"
      t.string :priority, null: false, default: "normal"
      t.date :due_on
      t.integer :position, null: false, default: 0
      t.datetime :completed_at

      t.timestamps
    end
    add_index :tasks, [ :church_id, :status, :position ]
    add_index :tasks, [ :church_id, :due_on ]
  end
end

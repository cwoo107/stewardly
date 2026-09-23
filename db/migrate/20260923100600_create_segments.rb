class CreateSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :segments do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.text :description
      t.jsonb :definition, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :segments, [ :church_id, :name ], unique: true
  end
end

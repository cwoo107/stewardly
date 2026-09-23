class CreateCustomFields < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_fields do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.string :options, array: true, null: false, default: []
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :custom_fields, [ :church_id, :key ], unique: true
    add_index :custom_fields, [ :church_id, :position ]
  end
end

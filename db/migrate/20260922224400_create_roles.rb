class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.references :church, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :permissions, array: true, null: false, default: []
      # Grants every permission, including ones added in later releases
      t.boolean :grants_all, null: false, default: false
      # Seeded roles that cannot be deleted
      t.boolean :system, null: false, default: false

      t.timestamps
    end
    add_index :roles, [ :church_id, :key ], unique: true
  end
end

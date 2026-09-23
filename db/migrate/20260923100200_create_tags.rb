class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.citext :name, null: false
      t.string :color, null: false, default: "gray"

      t.timestamps
    end
    add_index :tags, [ :church_id, :name ], unique: true

    create_table :taggings do |t|
      t.references :church, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true, index: false

      t.timestamps
    end
    add_index :taggings, [ :person_id, :tag_id ], unique: true
  end
end

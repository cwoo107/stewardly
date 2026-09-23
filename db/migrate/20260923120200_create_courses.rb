class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.references :church, null: false, foreign_key: true
      t.references :ministry, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :course_offerings do |t|
      t.references :church, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :leader, foreign_key: { to_table: :people }
      t.date :starts_on, null: false
      t.date :ends_on
      t.string :location_name
      t.integer :capacity
      t.boolean :enrollment_open, null: false, default: true

      t.timestamps
    end

    create_table :course_sessions do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :course_offering, null: false, foreign_key: true, index: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.date :local_date, null: false
      t.string :topic

      t.timestamps
    end
    add_index :course_sessions, [ :course_offering_id, :starts_at ]
    add_index :course_sessions, [ :church_id, :local_date ]

    create_table :enrollments do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :course_offering, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.string :status, null: false, default: "enrolled"
      t.datetime :completed_at
      t.datetime :withdrawn_at
      t.datetime :promoted_at

      t.timestamps
    end
    add_index :enrollments, [ :course_offering_id, :person_id ], unique: true
    add_index :enrollments, [ :course_offering_id, :status, :created_at ]

    create_table :session_attendances do |t|
      t.references :church, null: false, foreign_key: true
      t.references :course_session, null: false, foreign_key: true, index: false
      t.references :enrollment, null: false, foreign_key: true
      t.boolean :present, null: false, default: true

      t.timestamps
    end
    add_index :session_attendances, [ :course_session_id, :enrollment_id ], unique: true
  end
end

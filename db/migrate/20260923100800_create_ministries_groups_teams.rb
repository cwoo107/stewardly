class CreateMinistriesGroupsTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :ministries do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :ministries, [ :church_id, :name ], unique: true

    create_table :ministry_leaderships do |t|
      t.references :church, null: false, foreign_key: true
      t.references :ministry, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :ministry_leaderships, [ :ministry_id, :user_id ], unique: true

    create_table :groups do |t|
      t.references :church, null: false, foreign_key: true
      t.references :ministry, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :group_type, null: false, default: "small_group"
      t.integer :capacity
      t.integer :meeting_day # 0 = Sunday, like Date#wday
      t.time :meeting_time
      t.string :meeting_frequency, null: false, default: "weekly"
      t.boolean :active, null: false, default: true
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country, null: false, default: "US"
      t.st_point :location, geographic: true, srid: 4326
      t.datetime :geocoded_at
      t.string :geocode_error

      t.timestamps
    end
    add_index :groups, :location, using: :gist
    add_index :groups, [ :church_id, :group_type ]

    create_table :group_memberships do |t|
      t.references :church, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.date :joined_on, null: false

      t.timestamps
    end
    add_index :group_memberships, [ :group_id, :person_id ], unique: true

    create_table :teams do |t|
      t.references :church, null: false, foreign_key: true
      t.references :ministry, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    create_table :positions do |t|
      t.references :church, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    create_table :team_memberships do |t|
      t.references :church, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true
      t.string :role, null: false, default: "member"

      t.timestamps
    end
    add_index :team_memberships, [ :team_id, :person_id ], unique: true
  end
end

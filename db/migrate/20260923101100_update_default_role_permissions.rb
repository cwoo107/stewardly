# Brings existing churches' default roles up to the Phase 1 permission set.
# New churches get these from Role::DEFAULTS.
class UpdateDefaultRolePermissions < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
    "staff" => %w[ manage_ministries manage_people manage_tasks view_people view_precise_locations ],
    "care_team" => %w[ view_people view_prayer_requests ]
  }.freeze

  def up
    PERMISSIONS.each do |key, permissions|
      execute <<~SQL
        UPDATE roles SET permissions = ARRAY[#{permissions.map { |p| quote(p) }.join(", ")}]::varchar[]
        WHERE key = #{quote(key)} AND system
      SQL
    end
  end

  def down
    execute "UPDATE roles SET permissions = ARRAY['manage_people', 'view_precise_locations']::varchar[] WHERE key = 'staff' AND system"
    execute "UPDATE roles SET permissions = '{}' WHERE key = 'care_team' AND system"
  end
end

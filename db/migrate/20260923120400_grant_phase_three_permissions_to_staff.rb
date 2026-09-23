class GrantPhaseThreePermissionsToStaff < ActiveRecord::Migration[8.1]
  NEW = %w[ manage_announcements manage_courses manage_events manage_schedules ].freeze

  def up
    execute <<~SQL
      UPDATE roles SET permissions = ARRAY(SELECT DISTINCT unnest(permissions || ARRAY[#{NEW.map { |p| quote(p) }.join(", ")}]::varchar[]) ORDER BY 1)
      WHERE key = 'staff' AND system
    SQL
  end

  def down
    NEW.each { |permission| execute "UPDATE roles SET permissions = array_remove(permissions, #{quote(permission)}) WHERE key = 'staff' AND system" }
  end
end

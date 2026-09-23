class GrantSocialPermissionToStaff < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE roles SET permissions = ARRAY(SELECT DISTINCT unnest(permissions || ARRAY['manage_social']::varchar[]) ORDER BY 1)
      WHERE key = 'staff' AND system
    SQL
  end

  def down
    execute "UPDATE roles SET permissions = array_remove(permissions, 'manage_social') WHERE key = 'staff' AND system"
  end
end

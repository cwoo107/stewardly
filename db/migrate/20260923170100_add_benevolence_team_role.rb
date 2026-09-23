# Gives every existing church the "Benevolence team" system role (new churches get it
# from Role::DEFAULTS).
class AddBenevolenceTeamRole < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO roles (church_id, key, name, permissions, system, grants_all, created_at, updated_at)
      SELECT churches.id, 'benevolence_team', 'Benevolence team', ARRAY['manage_benevolence', 'view_benevolence', 'view_people']::varchar[], TRUE, FALSE, NOW(), NOW()
      FROM churches
      WHERE NOT EXISTS (SELECT 1 FROM roles WHERE roles.church_id = churches.id AND roles.key = 'benevolence_team')
    SQL
  end

  def down
    execute "DELETE FROM roles WHERE key = 'benevolence_team' AND system AND NOT EXISTS (SELECT 1 FROM user_roles WHERE user_roles.role_id = roles.id)"
  end
end

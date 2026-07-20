class ChangeMicrosoftTeamsDepartmentToArrayInHiringDetails < ActiveRecord::Migration[7.2]
  def up
    add_column :hiring_details, :microsoft_teams_department_array, :string, array: true, default: []

    execute <<~SQL
      UPDATE hiring_details
      SET microsoft_teams_department_array = string_to_array(microsoft_teams_department, ',')
      WHERE microsoft_teams_department IS NOT NULL AND microsoft_teams_department != ''
    SQL

    remove_column :hiring_details, :microsoft_teams_department
    rename_column :hiring_details, :microsoft_teams_department_array, :microsoft_teams_department
  end

  def down
    add_column :hiring_details, :microsoft_teams_department_string, :string

    execute <<~SQL
      UPDATE hiring_details
      SET microsoft_teams_department_string = array_to_string(microsoft_teams_department, ',')
    SQL

    remove_column :hiring_details, :microsoft_teams_department
    rename_column :hiring_details, :microsoft_teams_department_string, :microsoft_teams_department
  end
end

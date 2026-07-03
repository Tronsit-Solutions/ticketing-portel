class CreateHiringDetails < ActiveRecord::Migration[7.2]
  def change
    create_table :hiring_details do |t|
      t.references :ticket, null: false, foreign_key: true
      t.date    :start_date
      t.date    :date_of_birth
      t.string  :title_position
      t.boolean :is_provider, default: false, null: false
      t.string  :department
      t.string  :gender
      t.string  :cell_phone
      t.string  :badge_number
      t.string  :credentials_send_to
      t.string  :existing_pc_user
      t.text    :additional_info
      t.string  :pc_requirement
      t.string  :microsoft_teams_department

      # Multi-select fields stored as arrays
      t.string  :access_systems,        array: true, default: []
      t.string  :distribution_groups,   array: true, default: []

      t.timestamps
    end
  end
end

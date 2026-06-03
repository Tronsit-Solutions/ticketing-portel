class CreateTicketAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_assignments do |t|
      t.references :ticket,        null: false, foreign_key: true
      t.references :assigned_to,   null: false, foreign_key: { to_table: :users }
      t.references :assigned_from, null: true,  foreign_key: { to_table: :users }
      t.references :assigned_by,   null: false, foreign_key: { to_table: :users }
      t.text       :reason,        null: true
      t.timestamps
    end
  end
end

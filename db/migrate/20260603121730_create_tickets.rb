class CreateTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :tickets do |t|
      t.string     :ticket_type,  null: false
      t.string     :title,        null: false
      t.string     :status,       null: false, default: "open"
      t.references :location,     null: true,  foreign_key: true
      t.references :customer,     null: true,  foreign_key: { to_table: :users }
      t.references :assignee,     null: true,  foreign_key: { to_table: :users }
      t.references :assigned_by,  null: true,  foreign_key: { to_table: :users }
      t.references :resolved_by,  null: true,  foreign_key: { to_table: :users }
      t.boolean    :is_emailsent, null: false, default: false
      t.datetime   :assigned_at,  null: true
      t.datetime   :resolved_at,  null: true
      t.timestamps
    end
    add_index :tickets, :status
    add_index :tickets, :ticket_type
  end
end

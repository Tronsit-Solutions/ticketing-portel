class CreateTicketNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_notifications do |t|
      t.references :ticket,       null: false, foreign_key: true
      t.references :responded_by, null: true,  foreign_key: { to_table: :users }
      t.references :receiver,     null: true,  foreign_key: { to_table: :users }
      t.text       :details,      null: true
      t.string     :status,       null: false, default: "unread"
      t.timestamps
    end

    add_index :ticket_notifications, :status
  end
end

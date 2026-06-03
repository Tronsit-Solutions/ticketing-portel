class CreateTicketDetails < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_details do |t|
      t.references :ticket,       null: false, foreign_key: true
      t.references :sender,       null: true,  foreign_key: { to_table: :users }
      t.text       :details,      null: false
      t.string     :message_type, null: false, default: "customer_reply"
      t.string     :message_id,   null: true
      t.string     :mail_to,      null: true
      t.string     :mail_cc,      null: true
      t.string     :mail_subject, null: true
      t.boolean    :is_html,      null: false, default: false
      t.timestamps
    end

    add_index :ticket_details, :message_type
  end
end

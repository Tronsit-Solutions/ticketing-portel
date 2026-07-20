class MakeTicketIdOptionalOnTicketNotifications < ActiveRecord::Migration[7.2]
  def change
    change_column_null :ticket_notifications, :ticket_id, true
  end
end

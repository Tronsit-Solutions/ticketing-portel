class AddStructuredDataToTicketMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :ticket_messages, :structured_data, :jsonb, default: nil
  end
end

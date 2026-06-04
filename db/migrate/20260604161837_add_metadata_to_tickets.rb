class AddMetadataToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :metadata, :jsonb, default: {}, null: false
  end
end

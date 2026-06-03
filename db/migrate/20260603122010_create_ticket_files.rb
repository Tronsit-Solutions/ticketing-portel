class CreateTicketFiles < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_files do |t|
      t.references :ticket, null: false, foreign_key: true
      t.string     :image,  null: true
      t.string     :file,   null: true
      t.timestamps
    end
  end
end

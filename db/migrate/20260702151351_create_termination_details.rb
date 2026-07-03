class CreateTerminationDetails < ActiveRecord::Migration[7.2]
  def change
    create_table :termination_details do |t|
      t.references :ticket, null: false, foreign_key: true
      t.string  :termination_reason
      t.date    :termination_date
      t.string  :termination_time
      t.string  :email_address
      t.string  :key_card
      t.boolean :email_forward_needed,    default: false, null: false
      t.string  :email_forwarded_to
      t.boolean :historical_email_access, default: false, null: false
      t.text    :additional_instructions

      t.timestamps
    end
  end
end

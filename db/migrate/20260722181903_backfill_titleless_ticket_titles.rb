class BackfillTitlelessTicketTitles < ActiveRecord::Migration[7.1]
  def up
    Ticket::TITLELESS_TYPES.each do |ticket_type|
      label = Ticket::TYPE_LABELS[ticket_type]

      if ticket_type == "hiring_departure"
        execute <<~SQL.squish
          UPDATE tickets
          SET title = CASE
            WHEN metadata ->> 'request_type' = 'Termination' THEN 'Departure'
            ELSE 'Hiring'
          END
          WHERE ticket_type = 'hiring_departure'
        SQL
      else
        execute <<~SQL.squish
          UPDATE tickets
          SET title = #{connection.quote(label)}
          WHERE ticket_type = #{connection.quote(ticket_type)}
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

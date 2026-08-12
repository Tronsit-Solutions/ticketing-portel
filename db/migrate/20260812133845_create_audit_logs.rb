class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :actor, foreign_key: { to_table: :users }, null: true
      t.string  :actor_name,  null: false, default: "System"
      t.string  :actor_role
      t.string  :action,      null: false
      t.string  :category,    null: false
      t.references :auditable, polymorphic: true, null: true
      t.string  :auditable_label
      t.text    :description, null: false
      t.jsonb   :changed_data, default: {}, null: false
      t.string  :ip_address
      t.string  :user_agent

      t.timestamps
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :category
    add_index :audit_logs, :created_at
  end
end

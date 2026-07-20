class AddProviderFieldsToHiringDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :hiring_details, :billing_provider_name, :string
    add_column :hiring_details, :provider_npi, :string
    add_column :hiring_details, :q5_q6_modifier_required, :boolean, default: false, null: false
  end
end

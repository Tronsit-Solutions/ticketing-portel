require "rails_helper"

RSpec.describe "Admin::DropdownOptions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /admin/dropdown_options" do
    it "returns 200 and renders the new option form with data attributes wired for live position lookup" do
      get admin_dropdown_options_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("dropdown-option-position")
      expect(response.body).to include(next_position_admin_dropdown_options_path)
    end
  end

  describe "GET /admin/dropdown_options/next_position" do
    it "returns 1 for a category with no options yet" do
      get next_position_admin_dropdown_options_path(category: DropdownOption::HR_TYPES)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("position" => 1)
    end

    it "returns one past the current max position for the category" do
      create(:dropdown_option, category: DropdownOption::HR_TYPES, label: "Benefits")
      create(:dropdown_option, category: DropdownOption::HR_TYPES, label: "Payroll")

      get next_position_admin_dropdown_options_path(category: DropdownOption::HR_TYPES)
      expect(JSON.parse(response.body)).to eq("position" => 3)
    end

    it "does not mix positions across categories" do
      create(:dropdown_option, category: DropdownOption::HR_TYPES, label: "Benefits")
      create(:dropdown_option, category: DropdownOption::HR_TYPES, label: "Payroll")

      get next_position_admin_dropdown_options_path(category: DropdownOption::IDEA_TYPES)
      expect(JSON.parse(response.body)).to eq("position" => 1)
    end

    it "rejects an invalid category" do
      get next_position_admin_dropdown_options_path(category: "not_a_real_category")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

require "rails_helper"

RSpec.describe "Manager::Users", type: :request do
  let(:manager) { create(:user, :manager) }
  let(:agent)   { create(:user, :agent) }

  before { sign_in manager }

  describe "GET /manager/users/new" do
    it "returns 200" do
      get new_manager_user_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /manager/users" do
    it "creates a user and redirects to manager dashboard" do
      expect {
        post manager_users_path, params: {
          user: {
            fullname: "New Agent",
            email:    "newagent@example.com",
            password: "password123",
            password_confirmation: "password123",
            role:     "agent"
          }
        }
      }.to change(User, :count).by(1)
      expect(response).to redirect_to(manager_root_path)
    end

    it "renders new on invalid params" do
      post manager_users_path, params: { user: { email: "", role: "agent" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /manager/users/:id" do
    it "returns 200" do
      get manager_user_path(agent)
      expect(response).to have_http_status(:ok)
    end
  end

  context "when signed in as customer" do
    it "is unauthorized" do
      sign_in create(:user, :customer)
      get new_manager_user_path
      expect(response).to redirect_to(root_path)
    end
  end
end

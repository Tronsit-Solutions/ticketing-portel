require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:admin)   { create(:user, :admin) }
  let(:agent)   { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }

  describe "GET /users" do
    it "returns 200 for admin" do
      sign_in admin
      get users_path
      expect(response).to have_http_status(:ok)
    end

    it "is unauthorized for non-admin" do
      sign_in agent
      get users_path
      expect(response).to redirect_to(root_path)
    end

    it "redirects unauthenticated users" do
      get users_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "filters by role" do
      sign_in admin
      get users_path, params: { role: "agent" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /users/:id" do
    it "returns 200 for admin" do
      sign_in admin
      get user_path(agent)
      expect(response).to have_http_status(:ok)
    end

    it "is unauthorized for non-admin" do
      sign_in customer
      get user_path(agent)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /users/new" do
    it "returns 200 for admin" do
      sign_in admin
      get new_user_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users" do
    before { sign_in admin }

    it "creates a user and redirects" do
      expect {
        post users_path, params: {
          user: { fullname: "New User", email: "new@example.com", password: "pass1234", password_confirmation: "pass1234", role: "agent" }
        }
      }.to change(User, :count).by(1)
      expect(response).to redirect_to(users_path)
    end

    it "renders new on invalid params" do
      post users_path, params: { user: { email: "", fullname: "", role: "agent" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /users/:id" do
    before { sign_in admin }

    it "updates user and redirects" do
      patch user_path(customer), params: { user: { fullname: "Updated Name", email: customer.email, role: "customer" } }
      expect(customer.reload.fullname).to eq("Updated Name")
      expect(response).to redirect_to(user_path(customer))
    end
  end

  describe "DELETE /users/:id" do
    before { sign_in admin }

    it "deletes user and redirects" do
      target = create(:user, :customer)
      expect { delete user_path(target) }.to change(User, :count).by(-1)
      expect(response).to redirect_to(users_path)
    end
  end

  describe "PATCH /users/:id/deactivate" do
    before { sign_in admin }

    it "deactivates the user" do
      patch deactivate_user_path(customer)
      expect(customer.reload.is_active).to be false
      expect(response).to redirect_to(users_path)
    end
  end
end

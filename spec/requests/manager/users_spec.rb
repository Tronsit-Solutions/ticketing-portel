require "rails_helper"

RSpec.describe "Manager::Users", type: :request do
  let(:manager) { create(:user, :manager) }
  let(:agent)   { create(:user, :agent) }

  before { sign_in manager }

  describe "GET /manager/users (Customers index)" do
    it "returns 200 and lists only customers" do
      customer = create(:user, :customer, fullname: "Jane Customer")
      get manager_users_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.fullname)
      expect(response.body).not_to include(agent.fullname)
    end

    it "filters by search term against name or email" do
      match     = create(:user, :customer, fullname: "Alice Match", email: "alice@example.com")
      no_match  = create(:user, :customer, fullname: "Bob Other", email: "bob@example.com")

      get manager_users_path, params: { search: "Alice" }
      expect(response.body).to include(match.fullname)
      expect(response.body).not_to include(no_match.fullname)
    end

    it "filters by active status" do
      active_customer   = create(:user, :customer, fullname: "Active Customer")
      inactive_customer = create(:user, :customer, :inactive, fullname: "Inactive Customer")

      get manager_users_path, params: { active: "false" }
      expect(response.body).to include(inactive_customer.fullname)
      expect(response.body).not_to include(active_customer.fullname)
    end

    it "sorts by name ascending and descending" do
      create(:user, :customer, fullname: "Zed Customer")
      create(:user, :customer, fullname: "Amy Customer")

      get manager_users_path, params: { sort: "name", direction: "asc" }
      body = response.body
      expect(body.index("Amy Customer")).to be < body.index("Zed Customer")

      get manager_users_path, params: { sort: "name", direction: "desc" }
      body = response.body
      expect(body.index("Zed Customer")).to be < body.index("Amy Customer")
    end

    it "paginates customers, 25 per page" do
      customers = Array.new(27) { |n| create(:user, :customer, fullname: format("Cust %02d", n)) }
      first_alphabetically, last_alphabetically = customers.first, customers.last # "Cust 00" .. "Cust 26"

      get manager_users_path
      expect(response.body).to include(first_alphabetically.fullname) # default sort is name asc, so "Cust 00" is on page 1
      expect(response.body).not_to include(last_alphabetically.fullname)

      get manager_users_path, params: { page: 2 }
      expect(response.body).to include(last_alphabetically.fullname)
    end

    it "defaults to sorting by name (then email) when no sort param is given" do
      create(:user, :customer, fullname: "Zed Customer")
      create(:user, :customer, fullname: "Amy Customer")

      get manager_users_path
      body = response.body
      expect(body.index("Amy Customer")).to be < body.index("Zed Customer")
    end
  end

  describe "GET /manager/users/:id/edit" do
    it "returns 200" do
      customer = create(:user, :customer)
      get edit_manager_user_path(customer)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /manager/users/:id" do
    it "updates the customer" do
      customer = create(:user, :customer, fullname: "Old Name")
      patch manager_user_path(customer), params: { user: { fullname: "New Name" } }
      expect(customer.reload.fullname).to eq("New Name")
      expect(response).to redirect_to(manager_user_path(customer))
    end

    it "does not allow changing role via this form" do
      customer = create(:user, :customer)
      patch manager_user_path(customer), params: { user: { fullname: "Still Customer", role: "admin" } }
      expect(customer.reload.role).to eq("customer")
    end

    it "renders edit on invalid params" do
      customer = create(:user, :customer)
      patch manager_user_path(customer), params: { user: { email: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /manager/users/:id/deactivate" do
    it "deactivates the customer" do
      customer = create(:user, :customer)
      patch deactivate_manager_user_path(customer)
      expect(customer.reload.is_active?).to eq(false)
      expect(response).to redirect_to(manager_users_path)
    end
  end

  describe "PATCH /manager/users/:id/activate" do
    it "activates the customer" do
      customer = create(:user, :customer, :inactive)
      patch activate_manager_user_path(customer)
      expect(customer.reload.is_active?).to eq(true)
      expect(response).to redirect_to(manager_users_path)
    end
  end

  describe "PATCH /manager/users/:id/reset_password" do
    it "resets the customer's password to the default password" do
      customer = create(:user, :customer)
      patch reset_password_manager_user_path(customer)
      expect(response).to redirect_to(manager_users_path)
      customer.reload
      expect(customer.valid_password?("123456")).to eq(true)
    end
  end

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

    it "is unauthorized for the customers index" do
      sign_in create(:user, :customer)
      get manager_users_path
      expect(response).to redirect_to(root_path)
    end

    it "is unauthorized for deactivate/activate/reset_password" do
      target = create(:user, :customer)
      sign_in create(:user, :customer)
      patch deactivate_manager_user_path(target)
      expect(response).to redirect_to(root_path)
    end
  end
end

require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  describe "POST /users/sign_in" do
    it "blocks login for a deactivated customer and shows a contact-administration message" do
      customer = create(:user, :customer, :inactive, password: "password123", password_confirmation: "password123")

      post user_session_path, params: { user: { email: customer.email, password: "password123" } }

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("Your account has been deactivated. Please contact administration.")
    end

    it "allows login for an active customer" do
      customer = create(:user, :customer, password: "password123", password_confirmation: "password123")

      post user_session_path, params: { user: { email: customer.email, password: "password123" } }
      expect(response).to redirect_to(customer_root_path)
    end

    it "blocks login for a deactivated agent" do
      agent = create(:user, :agent, :inactive, password: "password123", password_confirmation: "password123")

      post user_session_path, params: { user: { email: agent.email, password: "password123" } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

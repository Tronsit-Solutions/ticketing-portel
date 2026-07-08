require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "redirects to sign-in page" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as admin" do
      it "redirects to admin dashboard" do
        sign_in create(:user, :admin)
        get root_path
        expect(response).to redirect_to(admin_root_path)
      end
    end

    context "when signed in as agent" do
      it "redirects to agent dashboard" do
        sign_in create(:user, :agent)
        get root_path
        expect(response).to redirect_to(agent_root_path)
      end
    end

    context "when signed in as manager" do
      it "redirects to manager dashboard" do
        sign_in create(:user, :manager)
        get root_path
        expect(response).to redirect_to(manager_root_path)
      end
    end

    context "when signed in as customer" do
      it "redirects to customer dashboard" do
        sign_in create(:user, :customer)
        get root_path
        expect(response).to redirect_to(customer_root_path)
      end
    end
  end
end

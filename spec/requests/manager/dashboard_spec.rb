require "rails_helper"

RSpec.describe "Manager::Dashboard", type: :request do
  describe "GET /manager" do
    context "when signed in as manager" do
      it "returns 200" do
        sign_in create(:user, :manager)
        get manager_root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as admin" do
      it "returns 200" do
        sign_in create(:user, :admin)
        get manager_root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as customer" do
      it "redirects away" do
        sign_in create(:user, :customer)
        get manager_root_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when not signed in" do
      it "redirects to sign-in" do
        get manager_root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

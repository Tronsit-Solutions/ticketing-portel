require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let(:admin)    { create(:user, :admin) }
  let(:customer) { create(:user, :customer) }
  let(:agent)    { create(:user, :agent) }

  describe "GET /admin" do
    context "when signed in as admin" do
      before { sign_in admin }

      it "returns 200" do
        get admin_root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as customer" do
      it "redirects away (unauthorized)" do
        sign_in customer
        get admin_root_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in as agent" do
      it "redirects away (unauthorized)" do
        sign_in agent
        get admin_root_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when not signed in" do
      it "redirects to sign-in" do
        get admin_root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

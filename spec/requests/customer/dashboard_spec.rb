require "rails_helper"

RSpec.describe "Customer::Dashboard", type: :request do
  describe "GET /customer" do
    context "when signed in as customer" do
      it "returns 200" do
        sign_in create(:user, :customer)
        get customer_root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not signed in" do
      it "redirects to sign-in" do
        get customer_root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /customer/wiki" do
    it "returns 200 for signed-in customer" do
      sign_in create(:user, :customer)
      get customer_wiki_path
      expect(response).to have_http_status(:ok)
    end
  end
end

require "rails_helper"

RSpec.describe "Forced password change", type: :request do
  let(:user) { create(:user, :customer) }
  let!(:temporary) { user.reset_to_temporary_password! }

  before { sign_in user }

  it "sends the user to choose a new password before anything else" do
    get tickets_path
    expect(response).to redirect_to(edit_password_change_path)

    get edit_password_change_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Choose a New Password")
  end

  it "accepts a new password, clears the flag and keeps the user signed in" do
    patch password_change_path, params: { user: { password: "BrandNew#Pass1", password_confirmation: "BrandNew#Pass1" } }
    expect(response).to redirect_to(root_path)

    user.reload
    expect(user.must_change_password?).to eq(false)
    expect(user.valid_password?("BrandNew#Pass1")).to eq(true)

    get tickets_path
    expect(response).to have_http_status(:ok)
  end

  it "rejects reusing the temporary password" do
    patch password_change_path, params: { user: { password: temporary, password_confirmation: temporary } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("must be different from your temporary password")
    expect(user.reload.must_change_password?).to eq(true)
  end

  it "rejects a confirmation that doesn't match" do
    patch password_change_path, params: { user: { password: "BrandNew#Pass1", password_confirmation: "Other#Pass2" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.must_change_password?).to eq(true)
  end

  it "doesn't bother users who have no pending change" do
    user.update!(must_change_password: false)
    get tickets_path
    expect(response).to have_http_status(:ok)
    get edit_password_change_path
    expect(response).to redirect_to(root_path)
  end
end

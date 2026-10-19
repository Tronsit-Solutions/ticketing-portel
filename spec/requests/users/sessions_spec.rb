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

    it "does not record any failed-login audit entries for a correct-credentials sign-in" do
      customer = create(:user, :customer, password: "password123", password_confirmation: "password123")

      post user_session_path, params: { user: { email: customer.email, password: "password123" } }

      expect(AuditLog.where(action: AuditLog::LOGIN_FAILED).count).to eq(0)
      expect(AuditLog.where(action: AuditLog::LOGIN, actor_id: customer.id).count).to eq(1)
    end

    it "records exactly one failed-login audit entry for wrong credentials" do
      customer = create(:user, :customer, password: "password123", password_confirmation: "password123")

      post user_session_path, params: { user: { email: customer.email, password: "wrong-password" } }

      expect(AuditLog.where(action: AuditLog::LOGIN_FAILED).count).to eq(1)
      expect(AuditLog.last.description).to include(customer.email)
    end
  end

  describe "account lockout" do
    let(:customer) { create(:user, :customer, password: "password123", password_confirmation: "password123") }

    def attempt(password)
      post user_session_path, params: { user: { email: customer.email, password: password } }
    end

    it "locks the account after #{Devise.maximum_attempts} wrong passwords, even for the right one" do
      Devise.maximum_attempts.times { attempt("wrong-password") }

      expect(customer.reload.access_locked?).to be true
      attempt("password123")
      expect(response).to have_http_status(:unprocessable_content)
      get customer_root_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "lets the user back in once the lock period has passed" do
      Devise.maximum_attempts.times { attempt("wrong-password") }

      travel(Devise.unlock_in + 1.minute) do
        attempt("password123")
        expect(response).to redirect_to(customer_root_path)
      end
    end

    it "says the account is locked and shows a countdown, from the locking attempt on" do
      freeze_time do
        Devise.maximum_attempts.times { attempt("wrong-password") }

        expect(response.body).to include(I18n.t("devise.failure.locked"))
        expect(response.body).to include(%(data-unlock-countdown-seconds-value="#{Devise.unlock_in.to_i}"))

        travel 5.minutes
        attempt("password123")
        expect(response.body).to include(I18n.t("devise.failure.locked"))
        expect(response.body).to include(%(data-unlock-countdown-seconds-value="#{(Devise.unlock_in - 5.minutes).to_i}"))
      end
    end

    it "shows no countdown before the account is locked" do
      attempt("wrong-password")

      expect(response.body).not_to include(I18n.t("devise.failure.locked"))
      expect(response.body).not_to include("unlock-countdown")
    end

    it "gives the same message for an unknown email as for a wrong password" do
      post user_session_path, params: { user: { email: "nobody@example.com", password: "x" } }
      unknown = flash[:alert]
      attempt("wrong-password")

      expect(flash[:alert]).to eq(unknown)
    end
  end

  describe "session timeout" do
    it "signs the user out after #{Devise.timeout_in.inspect} of inactivity" do
      customer = create(:user, :customer, password: "password123", password_confirmation: "password123")
      post user_session_path, params: { user: { email: customer.email, password: "password123" } }

      travel(Devise.timeout_in + 1.minute) do
        get customer_root_path
        expect(flash[:alert]).to eq(I18n.t("devise.failure.timeout"))
        follow_redirect!
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /users/sign_in" do
    it "does not record a failed-login audit entry just from visiting the login page" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(AuditLog.where(action: AuditLog::LOGIN_FAILED).count).to eq(0)
    end
  end
end

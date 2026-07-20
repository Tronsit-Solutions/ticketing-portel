require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:team).optional }
    it { is_expected.to have_many(:assigned_tickets).class_name("Ticket") }
    it { is_expected.to have_many(:customer_tickets).class_name("Ticket") }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:role).in_array(User::ROLES) }

    it "is valid with valid attributes" do
      expect(build(:user)).to be_valid
    end

    it "is invalid with a duplicate email" do
      create(:user, email: "test@example.com")
      expect(build(:user, email: "test@example.com")).not_to be_valid
    end

    it "is invalid with an unknown role" do
      expect(build(:user, role: "supervillain")).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:active_agent)    { create(:user, :agent, is_active: true) }
    let!(:inactive_agent)  { create(:user, :agent, is_active: false) }
    let!(:active_customer) { create(:user, :customer, is_active: true) }

    it ".agents returns only agents" do
      expect(User.agents).to include(active_agent, inactive_agent)
      expect(User.agents).not_to include(active_customer)
    end

    it ".customers returns only customers" do
      expect(User.customers).to include(active_customer)
      expect(User.customers).not_to include(active_agent)
    end

    it ".active returns only active users" do
      expect(User.active).to include(active_agent, active_customer)
      expect(User.active).not_to include(inactive_agent)
    end
  end

  describe "role predicate methods" do
    it "#admin? returns true for admin role" do
      expect(build(:user, :admin).admin?).to be true
    end

    it "#agent? returns true for agent role" do
      expect(build(:user, :agent).agent?).to be true
    end

    it "#manager? returns true for manager role" do
      expect(build(:user, :manager).manager?).to be true
    end

    it "#customer? returns true for customer role" do
      expect(build(:user, :customer).customer?).to be true
    end

    it "#admin? returns false for non-admin" do
      expect(build(:user, :customer).admin?).to be false
    end
  end

  describe "#active_for_authentication?" do
    it "returns true for an active user" do
      expect(build(:user, :customer, is_active: true).active_for_authentication?).to be true
    end

    it "returns false for a deactivated user" do
      expect(build(:user, :customer, is_active: false).active_for_authentication?).to be false
    end
  end

  describe "#inactive_message" do
    it "returns :deactivated for a deactivated user" do
      expect(build(:user, :customer, is_active: false).inactive_message).to eq(:deactivated)
    end
  end
end

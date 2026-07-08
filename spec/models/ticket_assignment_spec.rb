require "rails_helper"

RSpec.describe TicketAssignment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:assigned_to).class_name("User") }
    it { is_expected.to belong_to(:assigned_from).optional }
    it { is_expected.to belong_to(:assigned_by).class_name("User") }
  end

  describe "scopes" do
    let(:agent) { create(:user, :agent) }
    let(:other) { create(:user, :agent) }
    let!(:assignment) { create(:ticket_assignment, assigned_to: agent) }
    let!(:other_assignment) { create(:ticket_assignment, assigned_to: other) }

    it ".for_user returns assignments for that user" do
      expect(TicketAssignment.for_user(agent)).to include(assignment)
      expect(TicketAssignment.for_user(agent)).not_to include(other_assignment)
    end

    it ".recent orders descending by created_at" do
      assignments = TicketAssignment.recent.to_a
      expect(assignments).to eq(assignments.sort_by(&:created_at).reverse)
    end
  end

  it "is valid with valid attributes" do
    expect(build(:ticket_assignment)).to be_valid
  end
end

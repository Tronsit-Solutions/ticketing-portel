require "rails_helper"

RSpec.describe Team, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:manager).optional }
    it { is_expected.to have_many(:users).dependent(:nullify) }
    it { is_expected.to have_many(:members).class_name("User").dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:team) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }

    it "is valid with valid attributes" do
      expect(build(:team)).to be_valid
    end

    it "is invalid without a name" do
      expect(build(:team, name: nil)).not_to be_valid
    end
  end

  describe "scopes" do
    it ".ordered returns teams alphabetically" do
      create(:team, name: "Zebra Team")
      create(:team, name: "Alpha Team")
      names = Team.ordered.pluck(:name)
      expect(names).to eq(names.sort)
    end
  end
end

require "rails_helper"

RSpec.describe Location, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:tickets).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:location) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:abbreviation) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_uniqueness_of(:name) }

    it "is valid with valid attributes" do
      expect(build(:location)).to be_valid
    end
  end

  describe "scopes" do
    let!(:active_location)   { create(:location, is_active: true) }
    let!(:inactive_location) { create(:location, is_active: false) }

    it ".active returns only active locations" do
      expect(Location.active).to include(active_location)
      expect(Location.active).not_to include(inactive_location)
    end

    it ".ordered returns locations alphabetically" do
      locations = Location.ordered.to_a
      expect(locations.map(&:name)).to eq(locations.map(&:name).sort)
    end
  end
end

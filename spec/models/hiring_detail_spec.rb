require "rails_helper"

RSpec.describe HiringDetail, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:ticket) }
  end

  it "is valid with valid attributes" do
    expect(build(:hiring_detail)).to be_valid
  end

  it "defines ACCESS_SYSTEMS constant" do
    expect(HiringDetail::ACCESS_SYSTEMS).to include("CureMD", "Salesforce")
  end

  it "defines DISTRIBUTION_GROUPS constant" do
    expect(HiringDetail::DISTRIBUTION_GROUPS).to include("AKPC Enterprise")
  end

  it "defines PC_REQUIREMENTS constant" do
    expect(HiringDetail::PC_REQUIREMENTS).to include("They Need A New Pc", "Use Existing Pc")
  end
end

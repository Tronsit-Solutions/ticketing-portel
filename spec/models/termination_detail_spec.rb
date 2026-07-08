require "rails_helper"

RSpec.describe TerminationDetail, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:ticket) }
  end

  it "is valid with valid attributes" do
    expect(build(:termination_detail)).to be_valid
  end

  it "defines TERMINATION_REASONS constant" do
    expect(TerminationDetail::TERMINATION_REASONS).to include("Voluntary Resignation", "Retirement")
  end

  it "defines YES_NO_OPTIONS constant" do
    options = TerminationDetail::YES_NO_OPTIONS.map(&:last)
    expect(options).to include("yes", "no")
  end
end

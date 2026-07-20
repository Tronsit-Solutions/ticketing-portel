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

  it "defines TITLE_OPTIONS constant" do
    expect(HiringDetail::TITLE_OPTIONS).to eq([
      "Select Option",
      "Asst. Medical Billing Specialist",
      "Care Coordinator I",
      "Care Coordinator II",
      "Certified Athletic Trainer",
      "Certified Orthotic Fitter",
      "Certified Medical Coder",
      "Contact Center Agent",
      "Call Center Agent",
      "Call Center Supervisor",
      "Certified Medical Assistant",
      "Medical Billing Specialist",
      "Mid-Level",
      "Physician",
      "Practice Manager",
      "Regional Director",
      "Senior Medical Billing Specialist",
      "Surgical Tech",
      "Other"
    ])
  end

  it "defines DEPARTMENT_OPTIONS constant" do
    expect(HiringDetail::DEPARTMENT_OPTIONS).to eq([
      "Select Option",
      "AZPHX",
      "AZSUN",
      "KYLEX",
      "KYLOU",
      "NCCAR",
      "NCCHA",
      "NCGBO",
      "NCPIN",
      "NJWALL",
      "NYGC",
      "NYMAN",
      "NYSMI",
      "NYWP",
      "OHCIN",
      "OHDUB",
      "SCCOL",
      "TXBEL",
      "TXDAL",
      "TXKAT",
      "TXWEB",
      "TXWOO",
      "RCC"
    ])
  end

  it "is valid with provider-specific attributes" do
    hiring_detail = build(:hiring_detail, :provider)
    expect(hiring_detail).to be_valid
    expect(hiring_detail.billing_provider_name).to eq("Dr. Jane Smith")
    expect(hiring_detail.provider_npi).to eq("1234567890")
    expect(hiring_detail.q5_q6_modifier_required?).to eq(false)
  end

  it "defines Q5_Q6_MODIFIERS constant" do
    expect(HiringDetail::Q5_Q6_MODIFIERS).to eq(["Q5", "Q6"])
  end

  it "is valid with a selected Q5/Q6 modifier" do
    hiring_detail = build(:hiring_detail, :provider_with_modifier)
    expect(hiring_detail).to be_valid
    expect(hiring_detail.q5_q6_modifier_required?).to eq(true)
    expect(hiring_detail.q5_q6_modifier).to eq("Q5")
  end
end

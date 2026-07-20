class HiringDetail < ApplicationRecord
  belongs_to :ticket

  ACCESS_SYSTEMS = [
    "Softphone in Practice",
    "Softphone in RCC(CTM)",
    "CureMD",
    "Fluoroscopy",
    "VQ OrthoCare",
    "Salesforce"
  ].freeze

  DISTRIBUTION_GROUPS = [
    "AKPC Active Medical Staff",
    "AKPC Active Providers",
    "AKPC Enterprise",
    "AKPC Safety Commitee",
    "Compliance",
    "Human Resources AKPCorp"
  ].freeze

  TITLE_OPTIONS = [
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
  ].freeze

  DEPARTMENT_OPTIONS = [
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
  ].freeze

  PC_REQUIREMENTS = ["They Need A New Pc", "Use Existing Pc"].freeze

  Q5_Q6_MODIFIERS = ["Q5", "Q6"].freeze
end

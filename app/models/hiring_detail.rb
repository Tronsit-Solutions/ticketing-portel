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
    "Manager",
    "Director",
    "Physician",
    "Nurse",
    "Medical Assistant",
    "Administrative",
    "Other"
  ].freeze

  DEPARTMENT_OPTIONS = [
    "Select Option",
    "Administration",
    "Clinical",
    "Finance",
    "Human Resources",
    "Information Technology",
    "Operations",
    "Other"
  ].freeze

  PC_REQUIREMENTS = ["They Need A New Pc", "Use Existing Pc"].freeze
end

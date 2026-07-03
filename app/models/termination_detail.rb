class TerminationDetail < ApplicationRecord
  belongs_to :ticket

  TERMINATION_REASONS = [
    "Choose option",
    "Voluntary Resignation",
    "Involuntary Termination",
    "End of Contract",
    "Retirement",
    "Other"
  ].freeze

  YES_NO_OPTIONS = [["Choose option", ""], ["Yes", "yes"], ["No", "no"]].freeze
end

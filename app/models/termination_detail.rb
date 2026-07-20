class TerminationDetail < ApplicationRecord
  belongs_to :ticket

  TERMINATION_REASONS = [
    "Choose option",
    "End of Contract",
    "Involuntary Termination",
    "Retirement",
    "Voluntary Resignation",
    "Other"
  ].freeze

  YES_NO_OPTIONS = [["Choose option", ""], ["Yes", "yes"], ["No", "no"]].freeze
end

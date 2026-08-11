namespace :dropdown_options do
  desc "Seed the default dropdown option values for ticket forms and hiring/termination forms"
  task seed: :environment do
    flat_seeds = {
      DropdownOption::HR_TYPES => [
        "Benefits",
        "Compliance Question or Concern",
        "Legal Question or Concern",
        "Payroll Question or Request",
        "Personal Question or Concern",
        "Timesheet Question",
        "Health, dental & vision benefits",
        "401K program",
        "Goodly educational program",
        "Please include anonymous complaints",
        "Please include Issues & Incidents",
        "Replacement request for Key cards and deactivation of lost and/or stolen cards"
      ],
      DropdownOption::IDEA_TYPES => [
        "Practice Flow",
        "Paperwork/Form",
        "Service Improvement"
      ],
      DropdownOption::WORK_TYPES => [
        "Great Work by a Team Member",
        "Positive Patient Feedback"
      ],
      DropdownOption::CARECLOUD_ISSUE => [
        "Personal", "Patient", "Clinical", "Reports", "Document Manager", "Radiology",
        "Billing Tasks", "Settings", "Scheduler", "Provider Notes", "Breeze", "Bugs/Glitches", "Other"
      ],
      DropdownOption::CUREMD_ISSUE => [
        "Personal", "Patient", "Clinical", "Reports", "Document Manager", "Radiology",
        "Ad-hoc reporting/IZENDA", "Billing Tasks", "Settings", "Scheduler", "Provider Notes",
        "KIOSK", "Bugs/Glitches", "Other"
      ],
      DropdownOption::EHR_CHANGE_ISSUE => [
        "Patient", "Clinical", "Reports", "Document", "Radiology", "Ad-hoc reporting/IZENDA",
        "Billing Tasks", "Settings", "Scheduler", "Provider Notes", "KIOSK", "Bugs/Glitches", "Other"
      ],
      DropdownOption::HIRING_TITLE_POSITION => [
        "Asst. Medical Billing Specialist", "Call Center Agent", "Call Center Supervisor",
        "Care Coordinator I", "Care Coordinator II", "Certified Athletic Trainer",
        "Certified Medical Assistant", "Certified Medical Coder", "Certified Orthotic Fitter",
        "Contact Center Agent", "Medical Billing Specialist", "Mid-Level", "Physician",
        "Practice Manager", "Regional Director", "Senior Medical Billing Specialist",
        "Surgical Tech", "Other"
      ],
      DropdownOption::HIRING_DEPARTMENT => [
        "AZPHX", "AZSUN", "KYLEX", "KYLOU", "NCCAR", "NCCHA", "NCGBO", "NCPIN", "NJWALL",
        "NYGC", "NYMAN", "NYSMI", "NYWP", "OHCIN", "OHDUB", "RCC", "SCCOL", "TXBEL",
        "TXDAL", "TXKAT", "TXWEB", "TXWOO"
      ],
      DropdownOption::HIRING_ACCESS_SYSTEMS => [
        "CureMD", "Fluoroscopy", "Salesforce", "Softphone in Practice",
        "Softphone in RCC(CTM)", "VQ OrthoCare"
      ],
      DropdownOption::HIRING_DISTRIBUTION_GROUPS => [
        "AKPC Active Medical Staff", "AKPC Active Providers", "AKPC Enterprise",
        "AKPC Safety Commitee", "Compliance", "Human Resources AKPCorp"
      ],
      DropdownOption::TERMINATION_REASON => [
        "End of Contract",
        "Involuntary Termination",
        "Retirement",
        "Voluntary Resignation",
        "Other"
      ]
    }

    puts "\n==> Seeding dropdown options"
    created = 0

    flat_seeds.each do |category, values|
      values.each_with_index do |value, index|
        record = DropdownOption.find_or_create_by!(category: category, value: value) do |row|
          row.label    = value
          row.position = index
        end
        created += 1 if record.previously_new_record?
      end
    end

    # tronshealth_issue has one entry where the displayed label differs from the stored value
    [
      ["Bugs/Glitches", "Bugs/Glitches"],
      ["Clinical", "Clinical"],
      ["Check-In App", "Check-In App"],
      ["Documents", "Documents"],
      ["Patients", "Patients"],
      ["Provider Notes", "Provider Note"],
      ["Schedular", "Schedular"],
      ["Settings", "Settings"],
      ["Others", "Others"]
    ].each_with_index do |(label, value), index|
      record = DropdownOption.find_or_create_by!(category: DropdownOption::TRONSHEALTH_ISSUE, value: value) do |row|
        row.label    = label
        row.position = index
      end
      created += 1 if record.previously_new_record?
    end

    puts "    #{created} option(s) created, #{DropdownOption.count} total."
  end
end

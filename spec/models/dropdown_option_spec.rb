require "rails_helper"

RSpec.describe DropdownOption, type: :model do
  let(:category) { DropdownOption::HR_TYPES }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(DropdownOption.new(category: category, label: "Benefits")).to be_valid
    end

    it "requires a label" do
      option = DropdownOption.new(category: category, label: nil)
      expect(option).not_to be_valid
      expect(option.errors[:label]).to be_present
    end

    it "requires a unique label within the same category" do
      DropdownOption.create!(category: category, label: "Benefits")
      dup = DropdownOption.new(category: category, label: "benefits")
      expect(dup).not_to be_valid
      expect(dup.errors[:label]).to include("has already been taken")
    end

    it "allows the same label across different categories" do
      DropdownOption.create!(category: category, label: "Other")
      other = DropdownOption.new(category: DropdownOption::IDEA_TYPES, label: "Other")
      expect(other).to be_valid
    end

    it "requires a unique value within the same category" do
      DropdownOption.create!(category: category, label: "Benefits", value: "benefits")
      dup = DropdownOption.new(category: category, label: "Perks", value: "benefits")
      expect(dup).not_to be_valid
      expect(dup.errors[:value]).to include("has already been taken")
    end
  end

  describe "positioning" do
    it "appends new options to the end by default" do
      first  = DropdownOption.create!(category: category, label: "First")
      second = DropdownOption.create!(category: category, label: "Second")

      expect(first.position).to eq(1)
      expect(second.position).to eq(2)
    end

    it "shifts existing options down when inserting at a taken position" do
      first  = DropdownOption.create!(category: category, label: "First")
      second = DropdownOption.create!(category: category, label: "Second")

      inserted = DropdownOption.create!(category: category, label: "Inserted", position: first.position)

      expect(inserted.reload.position).to eq(1)
      expect(first.reload.position).to eq(2)
      expect(second.reload.position).to eq(3)
    end

    it "shifts intervening options back when an existing option moves to a later position" do
      first  = DropdownOption.create!(category: category, label: "First")
      second = DropdownOption.create!(category: category, label: "Second")
      third  = DropdownOption.create!(category: category, label: "Third")

      first.update!(position: 3)

      expect(first.reload.position).to eq(3)
      expect(second.reload.position).to eq(1)
      expect(third.reload.position).to eq(2)
    end

    it "shifts intervening options forward when an existing option moves to an earlier position" do
      first  = DropdownOption.create!(category: category, label: "First")
      second = DropdownOption.create!(category: category, label: "Second")
      third  = DropdownOption.create!(category: category, label: "Third")

      third.update!(position: 1)

      expect(first.reload.position).to eq(2)
      expect(second.reload.position).to eq(3)
      expect(third.reload.position).to eq(1)
    end

    it "closes the gap when an option is disabled" do
      first  = DropdownOption.create!(category: category, label: "First")
      second = DropdownOption.create!(category: category, label: "Second")
      third  = DropdownOption.create!(category: category, label: "Third")

      first.update!(is_active: false)

      expect(first.reload.position).to eq(1)
      expect(second.reload.position).to eq(1)
      expect(third.reload.position).to eq(2)
    end

    it "reinserts an option at its original position when re-enabled" do
      first  = DropdownOption.create!(category: category, label: "First")
      second = DropdownOption.create!(category: category, label: "Second")
      third  = DropdownOption.create!(category: category, label: "Third")

      first.update!(is_active: false)
      second.reload.update!(is_active: false)
      first.reload.update!(is_active: true)

      expect(first.reload.position).to eq(1)
      expect(second.reload.position).to eq(1)
      expect(third.reload.position).to eq(2)

      second.reload.update!(is_active: true)

      expect(first.reload.position).to eq(2)
      expect(second.reload.position).to eq(1)
      expect(third.reload.position).to eq(3)
    end
  end
end

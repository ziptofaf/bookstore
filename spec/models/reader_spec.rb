require "rails_helper"

RSpec.describe Reader, type: :model do
  describe "validations" do
    subject { build(:reader) }

    it { is_expected.to validate_presence_of(:card_number) }
    it { is_expected.to validate_presence_of(:full_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:card_number).ignoring_case_sensitivity }
    it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }
    it { is_expected.to allow_value("000123").for(:card_number) }
    it { is_expected.not_to allow_value("12345", "1234567", "abcdef", "123456\n").for(:card_number).with_message("must be a six-digit number") }
    it { is_expected.not_to allow_value("not-an-email").for(:email) }
  end

  it { is_expected.to have_many(:borrowings).dependent(:restrict_with_error) }

  it "normalizes the email" do
    expect(build(:reader, email: "  Ada@Example.COM ").email).to eq("ada@example.com")
  end
end

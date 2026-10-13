require "rails_helper"

RSpec.describe Book, type: :model do
  describe "validations" do
    subject { build(:book) }

    it { is_expected.to validate_presence_of(:serial_number) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_uniqueness_of(:serial_number).ignoring_case_sensitivity }
    it { is_expected.to allow_value("000123").for(:serial_number) }
    it { is_expected.not_to allow_value("12345", "1234567", "abc123", "123456\n").for(:serial_number).with_message("must be a six-digit number") }
  end

  describe "associations" do
    it { is_expected.to have_many(:borrowings).dependent(:delete_all) }
    it { is_expected.to have_one(:current_borrowing).class_name("Borrowing") }
  end

  describe "status" do
    let(:book) { create(:book) }

    it "is available without an active borrowing" do
      create(:borrowing, :returned, book: book)

      expect(book).not_to be_borrowed
      expect(book.status).to eq("available")
    end

    it "is borrowed with an active borrowing" do
      create(:borrowing, book: book)

      expect(book.reload).to be_borrowed
      expect(book.status).to eq("borrowed")
    end
  end

  describe ".with_status" do
    let!(:available) { create(:book) }
    let!(:borrowed) { create(:book, :borrowed) }

    it "filters available books" do
      expect(described_class.with_status("available")).to contain_exactly(available)
    end

    it "filters borrowed books" do
      expect(described_class.with_status("borrowed")).to contain_exactly(borrowed)
    end

    it "returns every book for a blank or unknown status" do
      expect(described_class.with_status(nil)).to contain_exactly(available, borrowed)
      expect(described_class.with_status("destroy_all")).to contain_exactly(available, borrowed)
    end
  end

  describe "#destroy" do
    it "deletes an available book together with its history" do
      book = create(:book)
      create(:borrowing, :returned, book: book)

      expect { book.destroy }.to change(described_class, :count).by(-1).and change(Borrowing, :count).by(-1)
    end

    it "refuses to delete a borrowed book" do
      book = create(:book, :borrowed)

      expect(book.destroy).to be(false)
      expect(book.errors.full_messages).to include("Cannot delete a book that is currently borrowed")
      expect(Borrowing.where(book: book)).to exist
    end
  end

  it "uses the serial number as URL param" do
    expect(build(:book, serial_number: "424242").to_param).to eq("424242")
  end
end

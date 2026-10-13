require "rails_helper"

RSpec.describe Borrowing, type: :model do
  it { is_expected.to belong_to(:book) }
  it { is_expected.to belong_to(:reader) }

  describe "loan dates" do
    it "defaults to a 30-day loan starting now" do
      travel_to Time.zone.local(2026, 10, 11, 12) do
        borrowing = create(:borrowing, borrowed_at: nil)

        expect(borrowing.borrowed_at).to eq(Time.current)
        expect(borrowing.due_date).to eq(Date.new(2026, 11, 10))
      end
    end

    it "keeps an explicitly given due date" do
      borrowing = create(:borrowing, due_date: Date.new(2030, 1, 1))

      expect(borrowing.due_date).to eq(Date.new(2030, 1, 1))
    end
  end

  describe "validations" do
    it "allows only one active borrowing per book" do
      existing = create(:borrowing)
      duplicate = build(:borrowing, book: existing.book)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:book_id]).to include("is already borrowed")
    end

    it "allows borrowing a book again once it was returned" do
      existing = create(:borrowing, :returned)

      expect(build(:borrowing, book: existing.book)).to be_valid
    end

    it "is backed by a database constraint for concurrent borrows" do
      existing = create(:borrowing)
      duplicate = build(:borrowing, book: existing.book, due_date: existing.due_date)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "scopes" do
    let!(:active) { create(:borrowing, due_date: Date.new(2026, 10, 14)) }
    let!(:returned) { create(:borrowing, :returned, due_date: Date.new(2026, 10, 14)) }

    it ".active excludes returned borrowings" do
      expect(described_class.active).to contain_exactly(active)
    end

    it ".due_on matches the due date" do
      expect(described_class.due_on(Date.new(2026, 10, 14))).to contain_exactly(active, returned)
      expect(described_class.due_on(Date.new(2026, 10, 15))).to be_empty
    end
  end

  describe "#return!" do
    it "closes the borrowing" do
      borrowing = create(:borrowing, borrowed_at: 1.day.ago)

      freeze_time do
        borrowing.return!

        expect(borrowing.reload.returned_at).to eq(Time.current)
        expect(borrowing).not_to be_active
      end
    end
  end
end

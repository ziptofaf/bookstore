require "rails_helper"

RSpec.describe Books::UpdateStatus do
  subject(:update_status) { described_class.call(book: book, status: status, card_number: card_number) }

  let(:book) { create(:book) }
  let(:reader) { create(:reader) }
  let(:card_number) { reader.card_number }

  context "when borrowing an available book" do
    let(:status) { "borrowed" }

    it "opens a 30-day borrowing for the reader" do
      travel_to Time.zone.local(2026, 10, 11, 9) do
        expect { update_status }.to change(Borrowing, :count).by(1)

        borrowing = book.reload.current_borrowing
        expect(borrowing).to have_attributes(reader: reader, borrowed_at: Time.current, due_date: Date.new(2026, 11, 10))
      end
    end

    context "with an unknown card number" do
      let(:card_number) { "999999" }

      it { expect { update_status }.to raise_error(described_class::UnknownReader, /999999/) }
    end
  end

  context "when borrowing an already borrowed book" do
    let(:status) { "borrowed" }

    before { create(:borrowing, book: book) }

    it { expect { update_status }.to raise_error(described_class::AlreadyBorrowed) }
  end

  context "when another request borrowed the book in the meantime" do
    let(:status) { "borrowed" }

    it "translates the unique index violation" do
      allow(book.borrowings).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      allow(book).to receive(:with_lock).and_yield

      expect { update_status }.to raise_error(described_class::AlreadyBorrowed)
    end
  end

  context "when returning a borrowed book" do
    let(:status) { "available" }
    let!(:borrowing) { create(:borrowing, book: book, borrowed_at: 5.days.ago) }
    let(:card_number) { nil }

    it "closes the active borrowing" do
      freeze_time do
        update_status

        expect(borrowing.reload.returned_at).to eq(Time.current)
        expect(book.reload).not_to be_borrowed
      end
    end
  end

  context "when returning an available book" do
    let(:status) { "available" }

    it { expect { update_status }.to raise_error(described_class::NotBorrowed) }
  end

  context "with an unknown status" do
    let(:status) { "lost" }

    it { expect { update_status }.to raise_error(described_class::InvalidStatus, /available, borrowed/) }
  end
end

require "rails_helper"

RSpec.describe ReturnReminderMailer, type: :mailer do
  let(:reader) { build_stubbed(:reader, full_name: "Ada Lovelace", email: "ada@example.com") }
  let(:book) { build_stubbed(:book, serial_number: "000042", title: "Solaris", author: "Stanisław Lem") }
  let(:borrowing) { build_stubbed(:borrowing, book: book, reader: reader, due_date: Date.new(2026, 10, 14)) }

  describe "#due_soon" do
    subject(:mail) { described_class.with(borrowing: borrowing).due_soon }

    it "reminds the reader 3 days ahead" do
      expect(mail.to).to eq([ "ada@example.com" ])
      expect(mail.from).to eq([ "library@example.com" ])
      expect(mail.subject).to eq('Reminder: "Solaris" is due on 2026-10-14')
      expect(mail.body.encoded).to include("Hello Ada Lovelace", "000042", "in 3 days, on 2026-10-14")
    end
  end

  describe "#due_today" do
    subject(:mail) { described_class.with(borrowing: borrowing).due_today }

    it "reminds the reader on the due date" do
      expect(mail.to).to eq([ "ada@example.com" ])
      expect(mail.subject).to eq('"Solaris" is due today')
      expect(mail.body.encoded).to include("Stanisław Lem", "due back at the library today, 2026-10-14")
    end
  end
end

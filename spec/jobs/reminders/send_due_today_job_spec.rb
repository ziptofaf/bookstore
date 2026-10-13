require "rails_helper"

RSpec.describe Reminders::SendDueTodayJob, type: :job do
  it_behaves_like "a return reminder sender", mailer_action: :due_today, sent_at_column: :due_today_reminder_sent_at

  describe ".pending_borrowings" do
    it "selects active borrowings due today that haven't had this reminder yet" do
      travel_to Date.new(2026, 10, 11) do
        pending = create(:borrowing, due_date: Date.new(2026, 10, 11))
        already_warned = create(:borrowing, due_date: Date.new(2026, 10, 11), due_soon_reminder_sent_at: 3.days.ago)
        create(:borrowing, due_date: Date.new(2026, 10, 14))
        create(:borrowing, :returned, due_date: Date.new(2026, 10, 11))
        create(:borrowing, due_date: Date.new(2026, 10, 11), due_today_reminder_sent_at: 1.hour.ago)

        expect(described_class.pending_borrowings).to contain_exactly(pending, already_warned)
      end
    end
  end

  it "sends the due_today email" do
    ActionMailer::Base.deliveries.clear

    described_class.perform_now([ create(:borrowing).id ])

    expect(ActionMailer::Base.deliveries.last.subject).to end_with("is due today")
  end
end

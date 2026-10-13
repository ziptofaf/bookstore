module Reminders
  class SendDueSoonJob < SendReturnJob
    def self.days_before_due = 3

    def self.sent_at_column = :due_soon_reminder_sent_at

    private

    def reminder_email(borrowing) = ReturnReminderMailer.with(borrowing: borrowing).due_soon
  end
end

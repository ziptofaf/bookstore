module Reminders
  class SendDueTodayJob < SendReturnJob
    def self.days_before_due = 0

    def self.sent_at_column = :due_today_reminder_sent_at

    private

    def reminder_email(borrowing) = ReturnReminderMailer.with(borrowing: borrowing).due_today
  end
end

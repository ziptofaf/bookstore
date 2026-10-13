module Reminders
  # Base for one sender per reminder kind (SendDueSoonJob, SendDueTodayJob). Separate classes let SchedulerJob tell
  # the kinds apart in Sidekiq, so one kind's batches never hold up the other kind's scheduler.
  # A borrowing is stamped only after its email went out, so a failed delivery is retried instead of being skipped,
  # and a retried batch doesn't email the readers it already reached.
  class SendReturnJob < ApplicationJob
    queue_as :default

    # A reminder is only useful around its due date: 3 retries within the hour, then the batch goes straight to
    # Sidekiq's Dead set instead of Sidekiq's own retries, which would keep going for weeks.
    retry_on StandardError, wait: 15.minutes, attempts: 4
    sidekiq_options retry: 0

    def self.pending_borrowings
      Borrowing.active.due_on(Date.current + days_before_due).where(sent_at_column => nil)
    end

    def perform(borrowing_ids)
      Borrowing.active.where(id: borrowing_ids, self.class.sent_at_column => nil).find_each do |borrowing|
        reminder_email(borrowing).deliver_now
        borrowing.update_column(self.class.sent_at_column, Time.current)
      end
    end
  end
end

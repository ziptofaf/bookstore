require "sidekiq/api"

module Reminders
  # Scheduled daily by sidekiq-cron (see config/schedule.yml), once per reminder kind.
  class SchedulerJob < ApplicationJob
    BATCH_SIZE = 500

    queue_as :default

    def perform(kind)
      sender =
        case kind
        when "due_soon" then SendDueSoonJob
        when "due_today" then SendDueTodayJob
        end

      # Batches still queued, awaiting a retry or running haven't stamped their borrowings yet, so they would be
      # handed out twice. Only the same sender matters: each kind stamps its own column.
      return retry_job(wait: 5.minutes) if in_progress?(sender)

      sender.pending_borrowings.in_batches(of: BATCH_SIZE) { |batch| sender.perform_later(batch.ids) }
    end

    private

    def in_progress?(sender)
      queued = Sidekiq::Queue.new(sender.queue_name).any? { it.display_class == sender.name }
      awaiting_retry = Sidekiq::ScheduledSet.new.any? { it.display_class == sender.name }
      running = Sidekiq::WorkSet.new.any? { |_process, _thread, work| work.job.display_class == sender.name }

      queued || awaiting_retry || running
    end
  end
end

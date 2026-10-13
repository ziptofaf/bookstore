require "rails_helper"

RSpec.describe Reminders::SchedulerJob, type: :job do
  let(:today) { Date.new(2026, 10, 11) }
  let(:queued_jobs) { [] }
  let(:awaiting_retry_jobs) { [] }
  let(:running_jobs) { [] }

  around { |example| travel_to(today) { example.run } }

  before do
    allow(Sidekiq::Queue).to receive(:new).and_return(queued_jobs)
    allow(Sidekiq::ScheduledSet).to receive(:new).and_return(awaiting_retry_jobs)
    allow(Sidekiq::WorkSet).to receive(:new).and_return(running_jobs)
  end

  def sidekiq_job(class_name)
    instance_double(Sidekiq::JobRecord, display_class: class_name)
  end

  def running(class_name)
    [ "process-1", "thread-1", instance_double(Sidekiq::Work, job: sidekiq_job(class_name)) ]
  end

  describe "due_soon" do
    subject(:perform) { described_class.perform_now("due_soon") }

    let!(:due_in_three_days) { create(:borrowing, due_date: today + 3) }

    before { create(:borrowing, due_date: today) }

    it "hands the pending borrowings to SendDueSoonJob" do
      expect { perform }.to have_enqueued_job(Reminders::SendDueSoonJob).with([ due_in_three_days.id ]).exactly(:once)
      expect(Reminders::SendDueTodayJob).not_to have_been_enqueued
    end

    it "splits the borrowings into batches" do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      more = create_list(:borrowing, 2, due_date: today + 3)

      perform

      expect(Reminders::SendDueSoonJob).to have_been_enqueued.with([ due_in_three_days.id, more.first.id ])
      expect(Reminders::SendDueSoonJob).to have_been_enqueued.with([ more.last.id ])
    end

    it "looks for in-progress batches on the sender's queue" do
      perform

      expect(Sidekiq::Queue).to have_received(:new).with("default")
    end

    shared_examples "waits for the batches in progress" do
      it "retries itself in 5 minutes instead of handing out batches" do
        expect { perform }.to have_enqueued_job(described_class).with("due_soon").at(5.minutes.from_now)
        expect(Reminders::SendDueSoonJob).not_to have_been_enqueued
      end
    end

    context "when a SendDueSoonJob is still queued" do
      let(:queued_jobs) { [ sidekiq_job("Reminders::SendDueSoonJob") ] }

      it_behaves_like "waits for the batches in progress"
    end

    context "when a SendDueSoonJob is waiting for a retry" do
      let(:awaiting_retry_jobs) { [ sidekiq_job("Reminders::SendDueSoonJob") ] }

      it_behaves_like "waits for the batches in progress"
    end

    context "when a SendDueSoonJob is still running" do
      let(:running_jobs) { [ running("Reminders::SendDueSoonJob") ] }

      it_behaves_like "waits for the batches in progress"
    end

    context "when only SendDueTodayJobs and other jobs are in progress" do
      let(:queued_jobs) { [ sidekiq_job("Reminders::SendDueTodayJob"), sidekiq_job("ReturnReminderMailer#due_soon") ] }
      let(:awaiting_retry_jobs) { [ sidekiq_job("Reminders::SendDueTodayJob"), sidekiq_job("Reminders::SchedulerJob") ] }
      let(:running_jobs) { [ running("Reminders::SendDueTodayJob") ] }

      it "hands out batches" do
        expect { perform }.to have_enqueued_job(Reminders::SendDueSoonJob).with([ due_in_three_days.id ])
      end
    end
  end

  describe "due_today" do
    let!(:due_today) { create(:borrowing, due_date: today) }

    it "hands the pending borrowings to SendDueTodayJob" do
      expect { described_class.perform_now("due_today") }
        .to have_enqueued_job(Reminders::SendDueTodayJob).with([ due_today.id ]).exactly(:once)
    end

    context "when a SendDueSoonJob is still running" do
      let(:running_jobs) { [ running("Reminders::SendDueSoonJob") ] }

      it "is not held up by it" do
        expect { described_class.perform_now("due_today") }.to have_enqueued_job(Reminders::SendDueTodayJob)
      end
    end
  end

  describe "config/schedule.yml" do
    let(:schedule) { YAML.load_file(Rails.root.join("config/schedule.yml")) }

    it "runs every reminder kind daily" do
      expect(schedule.values).to all(include("class" => described_class.name, "active_job" => true))
      expect(schedule.values.map { it["args"] }).to contain_exactly([ "due_soon" ], [ "due_today" ])
      schedule.each_value do |entry|
        expect(Fugit.parse_cron(entry["cron"]).rough_frequency).to eq(1.day.to_i)
      end
    end
  end
end

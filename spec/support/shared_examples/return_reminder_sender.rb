RSpec.shared_examples "a return reminder sender" do |mailer_action:, sent_at_column:|
  let(:deliveries) { ActionMailer::Base.deliveries }
  let(:borrowing) { create(:borrowing) }

  before { deliveries.clear }

  it "emails the reader through ReturnReminderMailer##{mailer_action}" do
    message = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    allow(ReturnReminderMailer).to receive(:with).and_return(double("parameterized mailer", mailer_action => message))

    described_class.perform_now([ borrowing.id ])

    expect(ReturnReminderMailer).to have_received(:with).with(borrowing: borrowing)
    expect(message).to have_received(:deliver_now)
  end

  it "delivers the email and stamps #{sent_at_column}" do
    freeze_time do
      described_class.perform_now([ borrowing.id ])

      expect(deliveries.map(&:to)).to eq([ [ borrowing.reader.email ] ])
      expect(borrowing.reload.public_send(sent_at_column)).to eq(Time.current)
    end
  end

  it "only emails the given borrowings" do
    other = create(:borrowing)

    described_class.perform_now([ borrowing.id ])

    expect(deliveries.flat_map(&:to)).not_to include(other.reader.email)
  end

  it "skips borrowings that were returned or already reminded in the meantime" do
    returned = create(:borrowing, :returned)
    reminded = create(:borrowing, sent_at_column => 1.hour.ago)

    described_class.perform_now([ returned.id, reminded.id ])

    expect(deliveries).to be_empty
  end

  describe "when the delivery fails" do
    before do
      message = instance_double(ActionMailer::MessageDelivery)
      allow(message).to receive(:deliver_now).and_raise(Net::ReadTimeout)
      allow(ReturnReminderMailer).to receive(:with).and_return(double("parameterized mailer", mailer_action => message))
    end

    it "leaves the borrowing unstamped and retries the batch in about 15 minutes" do
      freeze_time do
        described_class.perform_now([ borrowing.id ])

        expect(borrowing.reload.public_send(sent_at_column)).to be_nil
        expect(described_class).to have_been_enqueued.with([ borrowing.id ])
        expect(Time.at(enqueued_jobs.last[:at])).to be_between(15.minutes.from_now, 17.25.minutes.from_now)
      end
    end

    it "gives up after the 4th attempt" do
      described_class.perform_now([ borrowing.id ])
      2.times { ActiveJob::Base.execute(enqueued_jobs.pop) }

      expect { ActiveJob::Base.execute(enqueued_jobs.pop) }.to raise_error(Net::ReadTimeout)
      expect(ReturnReminderMailer).to have_received(:with).exactly(4).times
      expect(enqueued_jobs).to be_empty
    end

    it "leaves an exhausted batch to Sidekiq's Dead set instead of Sidekiq's own retries" do
      expect(described_class.get_sidekiq_options["retry"]).to eq(0)
    end
  end
end

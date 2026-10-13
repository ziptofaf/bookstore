# Preview at http://localhost:3000/rails/mailers/return_reminder_mailer (development only).
class ReturnReminderMailerPreview < ActionMailer::Preview
  def due_soon
    ReturnReminderMailer.with(borrowing: sample_borrowing).due_soon
  end

  def due_today
    ReturnReminderMailer.with(borrowing: sample_borrowing).due_today
  end

  private

  def sample_borrowing
    Borrowing.active.first || Borrowing.new(
      book: Book.new(serial_number: "000001", title: "Solaris", author: "Stanisław Lem"),
      reader: Reader.new(card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com"),
      borrowed_at: 27.days.ago,
      due_date: 3.days.from_now.to_date
    )
  end
end

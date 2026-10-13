class ReturnReminderMailer < ApplicationMailer
  before_action :load_borrowing

  def due_soon
    mail to: @reader.email, subject: "Reminder: \"#{@book.title}\" is due on #{@borrowing.due_date}"
  end

  def due_today
    mail to: @reader.email, subject: "\"#{@book.title}\" is due today"
  end

  private

  def load_borrowing
    @borrowing = params.fetch(:borrowing)
    @book = @borrowing.book
    @reader = @borrowing.reader
  end
end

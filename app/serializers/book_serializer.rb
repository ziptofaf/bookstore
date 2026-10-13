class BookSerializer
  def initialize(book, with_history: false)
    @book = book
    @with_history = with_history
  end

  def as_json(*)
    json = {
      serial_number: @book.serial_number,
      title: @book.title,
      author: @book.author,
      status: @book.status,
      current_borrowing: @book.current_borrowing && BorrowingSerializer.new(@book.current_borrowing).as_json
    }
    json[:borrowings] = @book.borrowings.latest_first.includes(:reader).map { BorrowingSerializer.new(it).as_json } if @with_history
    json
  end
end

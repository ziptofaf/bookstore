class BorrowingSerializer
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json(*)
    {
      borrowed_at: @borrowing.borrowed_at,
      due_date: @borrowing.due_date,
      returned_at: @borrowing.returned_at,
      reader: ReaderSerializer.new(@borrowing.reader).as_json
    }
  end
end

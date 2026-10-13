module Books
  class UpdateStatus
    class Error < StandardError; end
    class InvalidStatus < Error; end
    class UnknownReader < Error; end
    class AlreadyBorrowed < Error; end
    class NotBorrowed < Error; end

    def self.call(...) = new(...).call

    def initialize(book:, status: nil, card_number: nil)
      @book = book
      @status = status
      @card_number = card_number
    end

    def call
      # Locked to prevent race condition (so we can't lend the same book twice at the same time for instance).
      book.with_lock do
        case status
        when "borrowed" then borrow
        when "available" then give_back
        else raise InvalidStatus, "Status must be one of: #{Book::STATUSES.join(', ')}"
        end
      end
    rescue ActiveRecord::RecordNotUnique
      raise AlreadyBorrowed, "Book is already borrowed"
    end

    private

    attr_reader :book, :status, :card_number

    def borrow
      raise AlreadyBorrowed, "Book is already borrowed" if book.borrowed?

      book.borrowings.create!(reader: find_reader)
    end

    def give_back
      raise NotBorrowed, "Book is not borrowed" unless book.borrowed?

      book.current_borrowing.return!
    end

    def find_reader
      Reader.find_by(card_number: card_number) ||
        raise(UnknownReader, "Reader with card number #{card_number.inspect} not found")
    end
  end
end

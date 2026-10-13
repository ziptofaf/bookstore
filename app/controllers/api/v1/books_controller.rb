module Api
  module V1
    class BooksController < ApplicationController
      before_action :set_book, only: %i[show destroy]

      def index
        books, meta = paginate(Book.with_status(params[:status]).order(:id))
        books = books.includes(current_borrowing: :reader)

        render json: { books: books.map { BookSerializer.new(it) }, meta: meta }
      end

      def show
        render json: BookSerializer.new(@book, with_history: true)
      end

      def create
        book = Book.create!(book_params)

        render json: BookSerializer.new(book), status: :created, location: api_v1_book_url(book)
      end

      def destroy
        if @book.destroy
          head :no_content
        else
          render_errors @book.errors.full_messages, status: :conflict
        end
      end

      private

      def set_book
        @book = Book.find_by!(serial_number: params[:serial_number])
      end

      def book_params
        params.expect(book: %i[serial_number title author])
      end
    end
  end
end

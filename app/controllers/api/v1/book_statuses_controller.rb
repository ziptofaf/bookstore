module Api
  module V1
    class BookStatusesController < ApplicationController
      rescue_from Books::UpdateStatus::InvalidStatus, Books::UpdateStatus::UnknownReader do |error|
        render_errors error.message, status: :unprocessable_content
      end

      rescue_from Books::UpdateStatus::AlreadyBorrowed, Books::UpdateStatus::NotBorrowed do |error|
        render_errors error.message, status: :conflict
      end

      def update
        book = Book.find_by!(serial_number: params[:book_serial_number])
        Books::UpdateStatus.call(book: book, **permitted_params)

        render json: BookSerializer.new(book.reload)
      end

      private

      def permitted_params
        params.permit(:status, :card_number).to_h.symbolize_keys
      end
    end
  end
end

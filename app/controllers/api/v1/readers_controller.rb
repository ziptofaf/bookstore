module Api
  module V1
    class ReadersController < ApplicationController
      def index
        readers, meta = paginate(Reader.order(:id))

        render json: { readers: readers.map { ReaderSerializer.new(it) }, meta: meta }
      end

      def show
        render json: ReaderSerializer.new(Reader.find_by!(card_number: params[:card_number]))
      end

      def create
        reader = Reader.create!(reader_params)

        render json: ReaderSerializer.new(reader), status: :created, location: api_v1_reader_url(reader)
      end

      private

      def reader_params
        params.expect(reader: %i[card_number full_name email])
      end
    end
  end
end

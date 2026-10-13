class ApplicationController < ActionController::API
  include Paginatable

  rescue_from ActiveRecord::RecordNotFound do |error|
    render_errors "#{error.model || 'Record'} not found", status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_errors error.record.errors.full_messages, status: :unprocessable_content
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_errors error.message, status: :bad_request
  end

  private

  def render_errors(messages, status:)
    render json: { errors: Array(messages) }, status: status
  end
end

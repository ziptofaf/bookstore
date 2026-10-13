module JsonHelpers
  def json
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include JsonHelpers, type: :request
end

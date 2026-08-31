# `sign_in` / `sign_out` dentro dos request specs.
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end

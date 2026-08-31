# Lets specs call `build`/`create` directly instead of `FactoryBot.build`/`FactoryBot.create`.
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

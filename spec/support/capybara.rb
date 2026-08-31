require "capybara/rspec"

# Botões só de ícone (dropdown, fechar modal, stepper) são identificados pelo
# aria-label. Ligando isto, o spec passa a afirmar o nome acessível deles.
Capybara.enable_aria_label = true

# Chrome headless. O Selenium Manager resolve o driver sozinho.
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :headless_chrome }
end

require "webmock/rspec"

# Nenhum spec fala com a rede. localhost fica liberado porque é por onde o
# Capybara conversa com o servidor de teste e com o chromedriver.
WebMock.disable_net_connect!(allow_localhost: true)

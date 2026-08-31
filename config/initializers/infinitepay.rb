# Configuração do gateway. ENV ganha das credentials para o CI e o ambiente de
# teste rodarem sem a master key.
Rails.application.configure do
  credentials = Rails.application.credentials.infinitepay || {}

  config.x.infinitepay.handle ||= ENV["INFINITEPAY_HANDLE"].presence || credentials[:handle]
  config.x.infinitepay.base_url ||= ENV["INFINITEPAY_BASE_URL"].presence ||
                                    credentials[:base_url] ||
                                    "https://api.checkout.infinitepay.io"

  # Base pública do app, usada para montar redirect_url e webhook_url.
  # Aninhado de propósito: no primeiro nível, config.x.foo se auto-cria como
  # OrderedOptions — que é truthy — e o ||= nunca atribuiria.
  config.x.app.base_url ||= ENV["APP_BASE_URL"].presence || "http://localhost:3000"
end

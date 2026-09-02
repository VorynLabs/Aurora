# `freeze_time` / `travel_to` nos specs. Reserva, expiração e paid_at são
# comparações de tempo — congelar o relógio evita spec que falha por um
# milissegundo de diferença.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end

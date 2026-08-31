# Raiz provisória do painel, só para o /admin ter destino enquanto o CRUD de
# produtos não chega. O escopo seguinte assume esse lugar.
class Admin::DashboardController < Admin::BaseController
  def index; end
end

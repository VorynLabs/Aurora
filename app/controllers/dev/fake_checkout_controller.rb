# Página que substitui o checkout da InfinitePay quando o modo fake está
# ligado: mostra o pedido e deixa disparar o webhook à mão, para dar para
# percorrer o fluxo inteiro sem conta no gateway.
#
# A rota não é montada em produção. A checagem aqui é a segunda tranca: uma
# página que finge pagamento não pode existir onde há dinheiro de verdade.
class Dev::FakeCheckoutController < ApplicationController
  layout "catalog"

  before_action :block_in_production
  before_action :load_order

  def show
    @transaction_nsu = "fake-#{SecureRandom.uuid}"
  end

  private

  def block_in_production
    head :not_found if Rails.env.production?
  end

  def load_order
    @order = Order.find_by(order_nsu: params[:order_nsu])

    head :not_found if @order.nil?
  end
end

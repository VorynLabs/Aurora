# Fallback do webhook: pergunta à InfinitePay se um pedido pendente foi pago.
#
# Existe porque o webhook pode simplesmente não chegar — deploy no ar, rede
# fora, retentativa perdida. Sem isso, um pedido pago ficaria pendente até
# expirar e o estoque nunca baixaria.
#
# Alcança pedido expirado, não só pendente: com reserva de 7 minutos e a
# expiração rodando a cada 2, o pedido vira `expired` antes de qualquer job de
# conciliação passar por ele. Ficar só nos pendentes deixaria de fora
# justamente o pagamento que se perdeu. Ver Order.awaiting_reconciliation.
#
# A baixa é a mesma do webhook (Payments::SettlePaidOrder), então webhook
# atrasado e conciliação não se atropelam: quem chegar primeiro paga o pedido,
# o outro vira no-op.
class ReconcilePendingPaymentsJob < ApplicationJob
  include Payments::AmountMatching

  def perform
    Order.awaiting_reconciliation.find_each { |order| reconcile(order) }
  end

  private

  def reconcile(order)
    # Pedido que nunca chegou ao gateway não tem o que conciliar.
    return if order.transaction_id.blank? && order.payment_link_url.blank?

    check = client.payment_check(order)
    return unless check["paid"]
    return unless amount_matches?(order, check)

    Payments::SettlePaidOrder.new(order, check).call
  rescue InfinitepayClient::Error, Faraday::Error => e
    # Um pedido que não dá para consultar agora não pode parar a fila: os
    # outros continuam, e este volta na próxima rodada.
    Rails.logger.error("[ReconcilePendingPaymentsJob] #{order.order_nsu}: #{e.message}")
  end

  def client = @client ||= InfinitepayClient.new
end

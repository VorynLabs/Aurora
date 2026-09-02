module Payments
  # Passo 8 do SPEC 04: a baixa definitiva de estoque de um pedido já
  # comprovadamente pago.
  #
  # Vive separado do ProcessWebhook porque tem dois chamadores: o webhook
  # (caminho normal) e o ReconcilePendingPaymentsJob (fallback, quando o
  # webhook não chega). Os dois podem rodar para o mesmo pedido, então a baixa
  # precisa ser idempotente por si só, e não por confiar em quem chamou.
  #
  # A idempotência mora no lock do pedido: quem entrar primeiro marca `paid`,
  # quem entrar depois encontra o pedido já pago e não toca em estoque.
  class SettlePaidOrder
    Result = Struct.new(:ok?, :reason, :oversold, keyword_init: true)

    def initialize(order, check = {}, transaction_id: nil)
      @order = order
      @check = (check || {}).to_h.with_indifferent_access
      @transaction_id = transaction_id
    end

    def call
      oversold = []
      reason = nil

      ActiveRecord::Base.transaction do
        # Lock pessimista no pedido: serializa webhook duplicado, webhook
        # concorrente com o job de conciliação e retentativa da InfinitePay.
        order = Order.lock.find(@order.id)

        if order.paid?
          reason = :already_paid
        else
          oversold = settle(order)
          reason = :settled
        end
      end

      report_oversold(oversold) if oversold.any?
      @order.reload

      Result.new(ok?: true, reason: reason, oversold: oversold)
    end

    private

    def settle(order)
      oversold = []

      # Sempre na mesma ordem de variação, igual ao CreateCheckout: dois
      # pedidos com as mesmas variações em ordens diferentes fariam deadlock.
      order.order_items.order(:variant_id).each do |item|
        variant = Variant.lock.find(item.variant_id)

        # Só acontece quando a reserva já expirou e o estoque foi vendido para
        # outra pessoa nesse meio-tempo. O dinheiro entrou, então o pedido é
        # pago de qualquer forma — mas o estoque para no zero: negativo seria
        # prometer unidade que não existe.
        missing = item.quantity - variant.quantity
        oversold << { variant_id: variant.id, ordered: item.quantity, missing: missing } if missing.positive?

        variant.update!(
          quantity: [variant.quantity - item.quantity, 0].max,
          reserved: [variant.reserved - item.quantity, 0].max
        )
      end

      # `stock_conflict` grava o que o log sozinho não sustenta: o pedido está
      # pago e sem produto para entregar, e alguém precisa decidir entre
      # reembolso e reposição. Order.needs_review é essa fila.
      order.update!(status: :paid, paid_at: Time.current,
                    transaction_id: transaction_id_for(order),
                    stock_conflict: oversold.any?)

      oversold
    end

    def transaction_id_for(order)
      @transaction_id.presence || @check[:transaction_nsu].presence || order.transaction_id
    end

    # Alerta do caso "cliente paga depois da reserva expirar" (SPEC 04). Não dá
    # para desfazer a venda aqui; o que dá é não esconder o problema de quem
    # vai ter que resolver com o cliente.
    def report_oversold(oversold)
      Rails.logger.error(
        "[Payments::SettlePaidOrder] pedido #{@order.order_nsu} pago sem estoque suficiente: " \
        "#{oversold.map { |o| "variação #{o[:variant_id]} faltaram #{o[:missing]}" }.join('; ')}"
      )
    end
  end
end

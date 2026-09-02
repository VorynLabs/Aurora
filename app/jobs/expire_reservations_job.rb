# Devolve ao estoque a reserva de pedidos que ficaram pendentes além do prazo.
# Sem ele, um cliente que abandona o checkout seguraria as unidades para sempre.
#
# É o contrapeso da reserva feita em Payments::CreateCheckout: quem reserva
# marca `reserved_until`, e quem não paga até lá perde a vez.
class ExpireReservationsJob < ApplicationJob
  def perform
    Order.stale_pending.find_each { |order| expire(order) }
  end

  private

  def expire(order)
    ActiveRecord::Base.transaction do
      # Lock no pedido, e conferência de novo dentro dele: entre a busca e
      # aqui, o webhook pode ter pago este pedido. Expirar um pedido pago
      # devolveria estoque que já foi vendido.
      locked = Order.lock.find(order.id)
      next unless locked.pending? && locked.reserved_until&.past?

      # Mesma ordem de variação do checkout e da baixa, para não haver deadlock.
      locked.order_items.order(:variant_id).each do |item|
        variant = Variant.lock.find(item.variant_id)

        variant.update!(reserved: [variant.reserved - item.quantity, 0].max)
      end

      locked.update!(status: :expired)
    end
  end
end

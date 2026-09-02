require "rails_helper"

RSpec.describe ExpireReservationsJob do
  let(:variant) { create(:variant, quantity: 5, reserved: 2, price_cents: 4_990) }

  def order_with(status: :pending, reserved_until: 1.minute.ago, quantity: 2, on: variant)
    create(:order, status: status, reserved_until: reserved_until, total_cents: 9_980).tap do |order|
      create(:order_item, order: order, variant: on, quantity: quantity, price_cents: 4_990)
    end
  end

  describe "pedido pendente com a reserva vencida" do
    let!(:order) { order_with }

    it "devolve a reserva ao estoque" do
      described_class.perform_now

      expect(variant.reload).to have_attributes(reserved: 0, quantity: 5)
    end

    it "marca o pedido como expirado" do
      described_class.perform_now

      expect(order.reload).to be_expired
    end

    it "faz a variação voltar ao catálogo quando a reserva a tinha esvaziado" do
      product = create(:product, variant_quantity: 2, variant_reserved: 2)
      order_with(on: product.variants.sole)

      expect { described_class.perform_now }
        .to change { Product.visible_in_catalog.exists?(product.id) }.from(false).to(true)
    end
  end

  describe "pedidos que não deve tocar" do
    it "deixa em paz o pendente ainda dentro do prazo" do
      order = order_with(reserved_until: 10.minutes.from_now)

      described_class.perform_now

      expect(order.reload).to be_pending
      expect(variant.reload.reserved).to eq(2)
    end

    it "não devolve reserva de pedido já pago" do
      order = order_with(status: :paid)

      described_class.perform_now

      expect(order.reload).to be_paid
      expect(variant.reload.reserved).to eq(2)
    end

    it "não mexe em pedido já expirado" do
      order = order_with(status: :expired)

      described_class.perform_now

      expect(order.reload).to be_expired
      expect(variant.reload.reserved).to eq(2)
    end

    it "ignora pendente sem reserved_until" do
      order = order_with(reserved_until: nil)

      described_class.perform_now

      expect(order.reload).to be_pending
    end
  end

  it "devolve a reserva de cada item do pedido" do
    outra = create(:variant, quantity: 4, reserved: 3)
    order = order_with
    create(:order_item, order: order, variant: outra, quantity: 3, price_cents: 1_000)

    described_class.perform_now

    expect(variant.reload.reserved).to be_zero
    expect(outra.reload.reserved).to be_zero
  end

  it "não deixa reserved negativo quando a reserva já tinha sido devolvida" do
    variant.update!(reserved: 0)
    order_with

    described_class.perform_now

    expect(variant.reload.reserved).to be_zero
  end

  it "é idempotente: rodar de novo não devolve estoque duas vezes" do
    order_with(quantity: 2)

    2.times { described_class.perform_now }

    expect(variant.reload).to have_attributes(reserved: 0, quantity: 5)
  end

  it "expira vários pedidos numa rodada" do
    2.times { order_with(quantity: 1) }

    described_class.perform_now

    expect(Order.expired.count).to eq(2)
    expect(variant.reload.reserved).to be_zero
  end
end

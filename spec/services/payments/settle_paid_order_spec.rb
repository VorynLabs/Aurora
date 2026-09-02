require "rails_helper"

RSpec.describe Payments::SettlePaidOrder do
  let(:variant) { create(:variant, quantity: 5, reserved: 2, price_cents: 4_990) }
  let(:outra_variant) { create(:variant, quantity: 4, reserved: 1, price_cents: 1_000) }
  let(:order) { create(:order, status: :pending, total_cents: 9_980) }

  let(:check) { { "paid" => true, "amount" => 9_980, "paid_amount" => 9_980 } }

  before { create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990) }

  def settle(transaction_id: "trx-1") = described_class.new(order, check, transaction_id: transaction_id).call

  it "baixa quantity e solta reserved de cada item" do
    create(:order_item, order: order, variant: outra_variant, quantity: 1, price_cents: 1_000)

    settle

    expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
    expect(outra_variant.reload).to have_attributes(quantity: 3, reserved: 0)
  end

  it "marca o pedido como pago" do
    freeze_time do
      result = settle

      expect(result.ok?).to be(true)
      expect(result.reason).to eq(:settled)
      expect(order.reload).to be_paid
      expect(order.paid_at).to eq(Time.current)
      expect(order.transaction_id).to eq("trx-1")
    end
  end

  it "usa o transaction_nsu do payment_check quando não recebe transaction_id" do
    described_class.new(order, check.merge("transaction_nsu" => "trx-do-check")).call

    expect(order.reload.transaction_id).to eq("trx-do-check")
  end

  describe "idempotência" do
    it "não baixa duas vezes o mesmo pedido" do
      settle
      segunda = settle

      expect(segunda.reason).to eq(:already_paid)
      expect(variant.reload.quantity).to eq(3)
    end

    it "não mexe em nada num pedido que já nasceu pago" do
      order.update!(status: :paid, paid_at: 1.hour.ago, transaction_id: "trx-antigo")

      expect(settle.reason).to eq(:already_paid)
      expect(variant.reload).to have_attributes(quantity: 5, reserved: 2)
      expect(order.reload.transaction_id).to eq("trx-antigo")
    end
  end

  describe "pedido cuja reserva já expirou" do
    before do
      order.update!(status: :expired, reserved_until: 1.hour.ago)
      variant.update!(reserved: 0)
    end

    it "baixa o estoque e passa o pedido para pago" do
      settle

      expect(order.reload).to be_paid
      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
    end

    it "não marca conflito quando ainda há estoque para entregar" do
      settle

      expect(order.reload.stock_conflict).to be(false)
      expect(Order.needs_review).to be_empty
    end

    it "marca conflito de estoque no pedido, não só no log" do
      variant.update!(quantity: 0)
      allow(Rails.logger).to receive(:error)

      settle

      expect(order.reload).to be_paid
      expect(order.stock_conflict).to be(true)
      expect(Order.needs_review).to contain_exactly(order)
    end

    it "marca conflito quando o estoque cobre só parte do pedido" do
      variant.update!(quantity: 1)
      allow(Rails.logger).to receive(:error)

      settle

      expect(order.reload.stock_conflict).to be(true)
      expect(variant.reload.quantity).to be_zero
    end

    it "para o estoque no zero em vez de ficar negativo" do
      variant.update!(quantity: 1)
      allow(Rails.logger).to receive(:error)

      result = settle

      expect(variant.reload.quantity).to be_zero
      expect(result.oversold).to eq([{ variant_id: variant.id, ordered: 2, missing: 1 }])
    end

    it "alerta quando vendeu o que não tinha" do
      variant.update!(quantity: 0)
      allow(Rails.logger).to receive(:error)

      settle

      expect(Rails.logger).to have_received(:error)
        .with(/#{order.order_nsu}.*pago sem estoque suficiente/)
    end
  end

  it "não marca conflito numa baixa comum" do
    settle

    expect(order.reload.stock_conflict).to be(false)
  end

  it "não deixa reserved negativo quando a reserva já tinha sido devolvida" do
    variant.update!(reserved: 0)

    settle

    expect(variant.reload.reserved).to be_zero
  end
end

require "rails_helper"

RSpec.describe Order, type: :model do
  describe "order_nsu" do
    it "é gerado no create" do
      order = create(:order)

      expect(order.order_nsu).to match(/\Aord_[0-9a-f]{24}\z/)
    end

    it "é único entre pedidos" do
      primeiro = create(:order)
      duplicado = build(:order, order_nsu: primeiro.order_nsu)

      expect(duplicado).not_to be_valid
      expect(duplicado.errors[:order_nsu]).to be_present
    end

    it "não sobrescreve um nsu informado explicitamente" do
      order = create(:order, order_nsu: "ord_conciliacao_manual")

      expect(order.order_nsu).to eq("ord_conciliacao_manual")
    end
  end

  describe "status" do
    it "nasce pendente" do
      expect(create(:order)).to be_pending
    end

    it "passa de pendente para pago" do
      order = create(:order)

      order.paid!

      expect(order.reload).to be_paid
    end
  end

  describe ".stale_pending" do
    it "traz os pendentes cuja reserva já venceu" do
      vencido = create(:order, reserved_until: 1.minute.ago)

      expect(Order.stale_pending).to include(vencido)
    end

    it "ignora pendentes ainda dentro do prazo" do
      no_prazo = create(:order, reserved_until: 10.minutes.from_now)

      expect(Order.stale_pending).not_to include(no_prazo)
    end

    it "ignora pedidos já pagos, mesmo com a reserva vencida" do
      pago = create(:order, status: :paid, reserved_until: 1.minute.ago)

      expect(Order.stale_pending).not_to include(pago)
    end
  end

  describe "associações" do
    it "remove os itens junto com o pedido" do
      order = create(:order)
      create(:order_item, order: order)

      expect { order.destroy }.to change(OrderItem, :count).by(-1)
    end
  end

  describe ".needs_review" do
    it "traz só os pedidos pagos sem estoque para entregar" do
      conflito = create(:order, status: :paid, stock_conflict: true)
      create(:order, status: :paid)
      create(:order, status: :pending)

      expect(described_class.needs_review).to contain_exactly(conflito)
    end

    it "nasce vazia: pedido comum não tem conflito" do
      create(:order)

      expect(described_class.needs_review).to be_empty
    end
  end
end

require "rails_helper"

RSpec.describe ReconcilePendingPaymentsJob do
  let(:check_url) { "https://api.checkout.infinitepay.io/payment_check" }

  let(:variant) { create(:variant, quantity: 5, reserved: 2, price_cents: 4_990) }

  # Reserva vencendo em 1 minuto: dentro da janela de conciliação e ainda
  # pendente, que é o pedido que este job existe para resgatar.
  def pending_order(status: :pending, reserved_until: 1.minute.from_now, **attrs)
    create(:order, status: status, reserved_until: reserved_until, total_cents: 9_980,
           payment_link_url: "https://checkout.infinitepay.com.br/aurora_test?lenc=abc",
           **attrs).tap do |order|
      create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990)
    end
  end

  # Sem rede: toda consulta à InfinitePay é stub.
  def stub_check(paid: true, amount: 9_980, paid_amount: 9_980, status: 200)
    stub_request(:post, check_url).to_return(
      status: status,
      body: { "success" => true, "paid" => paid, "amount" => amount,
              "paid_amount" => paid_amount }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  describe "pedido pendente que consta pago" do
    let!(:order) { pending_order }

    before { stub_check }

    it "dá baixa no estoque" do
      described_class.perform_now

      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
    end

    it "marca o pedido como pago" do
      described_class.perform_now

      expect(order.reload).to be_paid
      expect(order.paid_at).to be_present
    end

    it "consulta a InfinitePay pelo pedido, mesmo sem webhook em mãos" do
      order.update!(transaction_id: "trx-antiga")

      described_class.perform_now

      expect(WebMock).to have_requested(:post, check_url).with { |request|
        body = JSON.parse(request.body)

        body["order_nsu"] == order.order_nsu && body["transaction_nsu"] == "trx-antiga"
      }
    end

    it "baixa quando o parcelamento com juros fez pagar mais que o pedido" do
      stub_check(amount: 9_980, paid_amount: 10_050)

      described_class.perform_now

      expect(variant.reload.quantity).to eq(3)
    end
  end

  describe "pedidos que continuam pendentes" do
    it "não baixa quando o pagamento não consta" do
      order = pending_order
      stub_check(paid: false)

      described_class.perform_now

      expect(order.reload).to be_pending
      expect(variant.reload).to have_attributes(quantity: 5, reserved: 2)
    end

    it "não baixa quando o valor pago é menor que o pedido" do
      order = pending_order
      stub_check(amount: 5_000, paid_amount: 5_000)

      described_class.perform_now

      expect(order.reload).to be_pending
      expect(variant.reload.quantity).to eq(5)
    end

    it "não consulta pedido que nunca chegou ao gateway" do
      pending_order(payment_link_url: nil)
      stub_check

      described_class.perform_now

      expect(WebMock).not_to have_requested(:post, check_url)
    end

    it "não consulta pendente com a reserva ainda longe de vencer" do
      pending_order(reserved_until: 25.minutes.from_now)
      stub_check

      described_class.perform_now

      expect(WebMock).not_to have_requested(:post, check_url)
    end
  end

  describe "idempotência" do
    it "ignora pedido já pago" do
      order = pending_order(status: :paid, paid_at: 1.hour.ago)
      stub_check

      described_class.perform_now

      expect(WebMock).not_to have_requested(:post, check_url)
      expect(variant.reload).to have_attributes(quantity: 5, reserved: 2)
      expect(order.reload.paid_at).to be_within(1.second).of(1.hour.ago)
    end

    it "ignora pedido já expirado" do
      pending_order(status: :expired, reserved_until: 1.hour.ago)
      stub_check

      described_class.perform_now

      expect(WebMock).not_to have_requested(:post, check_url)
    end

    it "rodar duas vezes não baixa o estoque duas vezes" do
      pending_order
      stub_check

      2.times { described_class.perform_now }

      expect(variant.reload.quantity).to eq(3)
    end
  end

  describe "quando a InfinitePay falha" do
    it "não baixa e deixa o pedido para a próxima rodada" do
      order = pending_order
      stub_check(status: 500)
      allow(Rails.logger).to receive(:error)

      expect { described_class.perform_now }.not_to raise_error

      expect(order.reload).to be_pending
      expect(variant.reload.quantity).to eq(5)
      expect(Rails.logger).to have_received(:error).with(/#{order.order_nsu}/)
    end

    it "um pedido que falha não impede a conciliação dos outros" do
      quebrado = pending_order
      allow(Rails.logger).to receive(:error)

      outra = create(:variant, quantity: 3, reserved: 1, price_cents: 1_000)
      ok = create(:order, status: :pending, reserved_until: 1.minute.from_now,
                  total_cents: 1_000, payment_link_url: "https://checkout.test/ok")
      create(:order_item, order: ok, variant: outra, quantity: 1, price_cents: 1_000)

      stub_request(:post, check_url)
        .with(body: hash_including("order_nsu" => quebrado.order_nsu))
        .to_raise(Faraday::ConnectionFailed)
      stub_request(:post, check_url)
        .with(body: hash_including("order_nsu" => ok.order_nsu))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: { "paid" => true, "amount" => 1_000, "paid_amount" => 1_000 }.to_json)

      described_class.perform_now

      expect(quebrado.reload).to be_pending
      expect(ok.reload).to be_paid
      expect(outra.reload).to have_attributes(quantity: 2, reserved: 0)
    end
  end
end

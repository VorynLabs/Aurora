require "rails_helper"

RSpec.describe Payments::ProcessWebhook do
  let(:check_url) { "https://api.checkout.infinitepay.io/payment_check" }

  # Produto de uma variação só: a fábrica de :variant criaria um produto com
  # outra variação junto, e aí o catálogo nunca esvaziaria.
  let(:product) { create(:product, variant_quantity: 5, variant_reserved: 2, variant_price_cents: 4_990) }
  let(:variant) { product.variants.sole }
  let(:order) { create(:order, status: :pending, total_cents: 9_980) }

  before { create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990) }

  def payload(overrides = {})
    {
      "invoice_slug" => "abc123",
      "amount" => 9_980,
      "paid_amount" => 9_980,
      "installments" => 1,
      "capture_method" => "pix",
      "transaction_nsu" => "trx-1",
      "order_nsu" => order.order_nsu,
      "receipt_url" => "https://comprovante.test/1"
    }.merge(overrides)
  end

  # Toda ida à InfinitePay é stubbada: nenhum spec deste arquivo toca a rede.
  def stub_check(paid: true, amount: 9_980, paid_amount: 9_980, status: 200)
    stub_request(:post, check_url).to_return(
      status: status,
      body: { "success" => true, "paid" => paid, "amount" => amount,
              "paid_amount" => paid_amount, "installments" => 1,
              "capture_method" => "pix" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  def process(data = payload) = described_class.new(data).call

  describe "caminho feliz" do
    before { stub_check }

    it "dá baixa no estoque e solta a reserva" do
      process

      variant.reload
      expect(variant.quantity).to eq(3)
      expect(variant.reserved).to eq(0)
    end

    it "marca o pedido como pago com a hora e a transação" do
      freeze_time do
        process

        order.reload
        expect(order).to be_paid
        expect(order.paid_at).to eq(Time.current)
        expect(order.transaction_id).to eq("trx-1")
      end
    end

    it "responde sucesso" do
      expect(process).to include(success: true, reason: :processed)
    end

    it "registra o evento como processado, com o payload recebido" do
      process

      event = WebhookEvent.sole
      expect(event.provider).to eq("infinitepay")
      expect(event.event_id).to eq("trx-1")
      expect(event.order_nsu).to eq(order.order_nsu)
      expect(event).to be_processed
      expect(event.processed_at).to be_present
      expect(event.payload["invoice_slug"]).to eq("abc123")
    end

    it "confirma o pagamento na InfinitePay antes de baixar" do
      process

      expect(WebMock).to have_requested(:post, check_url).with { |request|
        body = JSON.parse(request.body)

        body["handle"] == "aurora_test" &&
          body["order_nsu"] == order.order_nsu &&
          body["transaction_nsu"] == "trx-1" &&
          body["slug"] == "abc123"
      }
    end
  end

  describe "idempotência" do
    before { stub_check }

    it "trata o webhook duplicado como no-op: o estoque baixa uma vez só" do
      process
      segunda = process

      expect(segunda).to include(success: true, reason: :duplicate)
      expect(variant.reload.quantity).to eq(3)
    end

    it "não cria um segundo WebhookEvent para o mesmo transaction_nsu" do
      2.times { process }

      expect(WebhookEvent.count).to eq(1)
    end

    it "não consulta a InfinitePay de novo no duplicado" do
      2.times { process }

      expect(WebMock).to have_requested(:post, check_url).once
    end

    it "é no-op quando o pedido já está pago por outro caminho (job de conciliação)" do
      order.update!(status: :paid, paid_at: Time.current)

      expect(process).to include(success: true, reason: :already_paid)
      expect(variant.reload.quantity).to eq(5)
      expect(WebMock).not_to have_requested(:post, check_url)
    end
  end

  describe "pagamento não confirmado" do
    it "não baixa quando o payment_check diz paid: false" do
      stub_check(paid: false)

      result = process

      expect(result[:success]).to be(false)
      expect(result[:message]).to match(/não confirmado/)
      expect(variant.reload.quantity).to eq(5)
      expect(order.reload).to be_pending
      expect(WebhookEvent.sole).to be_ignored
    end

    it "não baixa quando o valor pago é menor que o pedido" do
      stub_check(amount: 5_000, paid_amount: 5_000)

      result = process

      expect(result[:success]).to be(false)
      expect(result[:message]).to match(/menor/)
      expect(variant.reload.quantity).to eq(5)
      expect(variant.reload.reserved).to eq(2)
      expect(WebhookEvent.sole).to be_ignored
    end

    it "ignora os valores que vieram no corpo do webhook e acredita só no payment_check" do
      stub_check(amount: 10, paid_amount: 10)

      result = process(payload("amount" => 999_999, "paid_amount" => 999_999))

      expect(result[:success]).to be(false)
      expect(variant.reload.quantity).to eq(5)
    end

    it "baixa normalmente quando o parcelamento com juros faz paid_amount passar do total" do
      stub_check(amount: 9_980, paid_amount: 10_050)

      expect(process).to include(success: true, reason: :processed)
      expect(variant.reload.quantity).to eq(3)
    end

    it "baixa quando só o paid_amount cobre o pedido" do
      stub_check(amount: 9_000, paid_amount: 10_050)

      expect(process).to include(success: true, reason: :processed)
      expect(variant.reload.quantity).to eq(3)
    end
  end

  describe "payloads que não dão para processar" do
    it "recusa pedido inexistente sem consultar a InfinitePay" do
      stub_check

      result = process(payload("order_nsu" => "ord_nao_existe"))

      expect(result).to eq(success: false, message: "pedido não encontrado")
      expect(WebMock).not_to have_requested(:post, check_url)
      expect(WebhookEvent.sole).to be_failed
    end

    it "recusa webhook sem transaction_nsu, antes de gravar evento" do
      result = process(payload("transaction_nsu" => nil))

      expect(result[:success]).to be(false)
      expect(result[:message]).to match(/transaction_nsu/)
      expect(WebhookEvent.count).to be_zero
    end

    it "recusa webhook sem order_nsu" do
      result = process(payload("order_nsu" => ""))

      expect(result[:success]).to be(false)
      expect(result[:message]).to match(/order_nsu/)
      expect(WebhookEvent.count).to be_zero
    end

    it "não baixa estoque de pedido cancelado" do
      order.update!(status: :canceled)
      stub_check

      result = process

      expect(result[:success]).to be(false)
      expect(variant.reload.quantity).to eq(5)
      expect(WebhookEvent.sole).to be_ignored
    end

    it "aceita payload com chaves símbolo (vindo de job, não do controller)" do
      stub_check

      expect(process(payload.symbolize_keys)).to include(success: true, reason: :processed)
    end
  end

  describe "quando a InfinitePay falha no double-check" do
    it "não baixa e pede reenvio quando o payment_check responde erro" do
      stub_check(status: 500)

      result = process

      expect(result[:success]).to be(false)
      expect(variant.reload.quantity).to eq(5)
      expect(WebhookEvent.sole).to be_failed
    end

    it "não baixa quando a conexão cai" do
      stub_request(:post, check_url).to_raise(Faraday::ConnectionFailed)

      expect(process[:success]).to be(false)
      expect(variant.reload.quantity).to eq(5)
    end

    it "processa na retentativa da InfinitePay depois de uma falha nossa" do
      stub_check(status: 500)
      process

      stub_check
      expect(process).to include(success: true, reason: :processed)
      expect(variant.reload.quantity).to eq(3)
      expect(WebhookEvent.count).to eq(1)
      expect(WebhookEvent.sole).to be_processed
    end
  end

  describe "efeitos no catálogo" do
    it "faz a variação zerada sumir do catálogo, sem código extra" do
      # Sem reserva pendente: a variação está no catálogo até a baixa zerá-la.
      variant.update!(quantity: 2, reserved: 0)
      stub_check

      expect { process }
        .to change { Product.visible_in_catalog.exists?(variant.product_id) }.from(true).to(false)
    end
  end

  describe "pagamento que chega depois da reserva expirar" do
    it "baixa mesmo assim: o dinheiro entrou" do
      order.update!(status: :expired, reserved_until: 1.hour.ago)
      variant.update!(reserved: 0)
      stub_check

      expect(process).to include(success: true, reason: :processed)
      expect(order.reload).to be_paid
      expect(variant.reload.quantity).to eq(3)
    end

    it "não marca conflito quando ainda há estoque" do
      order.update!(status: :expired, reserved_until: 1.hour.ago)
      variant.update!(reserved: 0)
      stub_check

      process

      expect(order.reload).to be_paid
      expect(order.stock_conflict).to be(false)
    end

    it "marca o pedido para revisão quando pagou e não há o que entregar" do
      # O cenário inteiro: reserva expira, outra pessoa leva a última unidade,
      # e só então chega o webhook do pagamento anterior.
      order.update!(status: :expired, reserved_until: 1.hour.ago)
      variant.update!(quantity: 0, reserved: 0)
      stub_check
      allow(Rails.logger).to receive(:error)

      expect(process).to include(success: true, reason: :processed)

      expect(order.reload).to be_paid
      expect(order.stock_conflict).to be(true)
      expect(Order.needs_review).to contain_exactly(order)
      expect(variant.reload.quantity).to be_zero
      expect(Rails.logger).to have_received(:error).with(/pago sem estoque suficiente/)
    end

    it "não deixa o estoque ficar negativo quando as unidades já foram vendidas" do
      order.update!(status: :expired, reserved_until: 1.hour.ago)
      variant.update!(quantity: 1, reserved: 0)
      stub_check

      allow(Rails.logger).to receive(:error)

      expect(process).to include(success: true, reason: :processed)
      expect(variant.reload.quantity).to be_zero
      expect(order.reload).to be_paid
      expect(Rails.logger).to have_received(:error).with(/pago sem estoque suficiente/)
    end
  end
end

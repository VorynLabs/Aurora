require "rails_helper"

RSpec.describe "Webhook da InfinitePay", type: :request do
  let(:check_url) { "https://api.checkout.infinitepay.io/payment_check" }

  let(:product) { create(:product, variant_quantity: 5, variant_reserved: 2, variant_price_cents: 4_990) }
  let(:variant) { product.variants.sole }
  let(:order) { create(:order, status: :pending, total_cents: 9_980) }

  before { create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990) }

  def stub_check(paid: true, amount: 9_980, paid_amount: 9_980)
    stub_request(:post, check_url).to_return(
      status: 200,
      body: { "success" => true, "paid" => paid, "amount" => amount, "paid_amount" => paid_amount }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  def payload(overrides = {})
    {
      invoice_slug: "abc123",
      amount: 9_980,
      paid_amount: 9_980,
      installments: 1,
      capture_method: "pix",
      transaction_nsu: "trx-1",
      order_nsu: order.order_nsu,
      receipt_url: "https://comprovante.test/1",
      items: [{ quantity: 2, price: 4_990, description: "Camiseta básica — Preta / 1" }]
    }.merge(overrides)
  end

  # A InfinitePay posta JSON sem sessão nem token: a rota tem que aceitar assim.
  def post_webhook(data = payload)
    post "/webhooks/infinitepay", params: data.to_json,
         headers: { "Content-Type" => "application/json" }
  end

  describe "pagamento confirmado" do
    before { stub_check }

    it "responde 200 com success: true" do
      post_webhook

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("success" => true, "message" => nil)
    end

    it "dá baixa no estoque e paga o pedido" do
      post_webhook

      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
      expect(order.reload).to be_paid
    end

    it "aceita a entrega repetida sem baixar de novo" do
      2.times { post_webhook }

      expect(response).to have_http_status(:ok)
      expect(variant.reload.quantity).to eq(3)
    end
  end

  describe "pagamento não confirmado" do
    it "responde 400 com o motivo quando o payment_check diz que não foi pago" do
      stub_check(paid: false)

      post_webhook

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["success"]).to be(false)
      expect(response.parsed_body["message"]).to be_present
      expect(variant.reload.quantity).to eq(5)
    end

    it "responde 400 para pedido inexistente" do
      post_webhook(payload(order_nsu: "ord_nao_existe"))

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["success"]).to be(false)
    end

    it "responde 400 para payload sem transaction_nsu" do
      post_webhook(payload(transaction_nsu: nil))

      expect(response).to have_http_status(:bad_request)
    end
  end

  it "não exige token CSRF, mesmo com a proteção ligada" do
    stub_check
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post_webhook

    expect(response).to have_http_status(:ok)
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  it "aceita corpo form-urlencoded, não só JSON" do
    stub_check

    post "/webhooks/infinitepay", params: payload.except(:items)

    expect(response).to have_http_status(:ok)
    expect(order.reload).to be_paid
  end
end

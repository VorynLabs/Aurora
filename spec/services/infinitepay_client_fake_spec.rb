require "rails_helper"

# Modo fake: fluxo de pagamento em desenvolvimento sem conta na InfinitePay e
# sem rede. A suíte roda com o modo desligado, então cada exemplo liga na mão.
RSpec.describe InfinitepayClient, "em modo fake" do
  subject(:client) { described_class.new(fake: true) }

  let(:links_url) { "https://api.checkout.infinitepay.io/links" }
  let(:check_url) { "https://api.checkout.infinitepay.io/payment_check" }

  let(:order) { create(:order, order_nsu: "ord_ab12cd34ef56", total_cents: 9_980) }
  let(:variant) { create(:variant, price_cents: 4_990) }

  before { create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990) }

  describe ".fake_enabled?" do
    def enabled?(env, flag) = described_class.fake_enabled?(env: ActiveSupport::StringInquirer.new(env), flag: flag)

    it "nunca liga em produção, nem com a flag ligada" do
      expect(enabled?("production", "true")).to be(false)
      expect(enabled?("production", nil)).to be(false)
    end

    it "liga sozinho em development" do
      expect(enabled?("development", nil)).to be(true)
    end

    it "fica desligado em test, para a suíte exercitar o caminho real" do
      expect(enabled?("test", nil)).to be(false)
    end

    it "obedece a flag fora de produção" do
      expect(enabled?("test", "true")).to be(true)
      expect(enabled?("development", "false")).to be(false)
      expect(enabled?("development", "0")).to be(false)
    end

    it "só liga com um sim explícito: o resto é não" do
      expect(enabled?("test", "talvez")).to be(false)
      expect(enabled?("test", "TRUE")).to be(true)
      expect(enabled?("test", " 1 ")).to be(true)
    end
  end

  describe "#create_link" do
    it "devolve a URL do checkout simulado, com o pedido na query" do
      url = client.create_link(order)

      expect(url).to eq("https://aurora.test/dev/fake_checkout?order_nsu=ord_ab12cd34ef56")
    end

    it "não toca na rede" do
      client.create_link(order)

      expect(WebMock).not_to have_requested(:post, links_url)
    end

    it "funciona sem handle configurado, que é o caso do desenvolvimento" do
      sem_handle = described_class.new(handle: "", fake: true)

      expect { sem_handle.create_link(order) }.not_to raise_error
    end

    it "continua recusando pedido sem itens" do
      vazio = create(:order)

      expect { client.create_link(vazio) }.to raise_error(ArgumentError, /sem itens/)
    end
  end

  describe "#payment_check" do
    it "aprova o pagamento no formato do SPEC 04" do
      expect(client.payment_check(order)).to eq(
        "success" => true, "paid" => true,
        "amount" => 9_980, "paid_amount" => 9_980,
        "installments" => 1, "capture_method" => "pix"
      )
    end

    it "reflete o total do pedido, para o amount_matches? aprovar" do
      order.update!(total_cents: 12_345)

      check = client.payment_check(order)

      expect(check["amount"]).to eq(12_345)
      expect(check["paid_amount"]).to eq(12_345)
    end

    it "não toca na rede" do
      client.payment_check(order, "transaction_nsu" => "trx-1")

      expect(WebMock).not_to have_requested(:post, check_url)
    end

    it "aceita a mesma assinatura de sempre, com e sem payload" do
      expect(client.payment_check(order)).to include("paid" => true)
      expect(client.payment_check(order, {})).to include("paid" => true)
    end

    it "funciona sem handle configurado" do
      sem_handle = described_class.new(handle: "", fake: true)

      expect(sem_handle.payment_check(order)).to include("paid" => true)
    end
  end

  describe "com a flag desligada" do
    subject(:real) { described_class.new(fake: false) }

    it "volta a falar HTTP" do
      stub_request(:post, links_url).to_return(
        status: 200, body: { "url" => "https://checkout.infinitepay.com.br/x" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect(real.create_link(order)).to eq("https://checkout.infinitepay.com.br/x")
      expect(WebMock).to have_requested(:post, links_url)
    end

    it "é o padrão da suíte" do
      expect(described_class.new).not_to be_fake
    end
  end

  describe "o fluxo inteiro sem rede" do
    it "abre o checkout e liquida pelo webhook" do
      variant.update!(quantity: 5, reserved: 0)
      cart = Cart.new({}).tap { _1.add(variant.id, 2) }

      result = Payments::CreateCheckout.new(cart, client: client).call

      expect(result.ok?).to be(true)
      expect(result.payment_url).to include("/dev/fake_checkout")

      webhook = Payments::ProcessWebhook.new(
        { "order_nsu" => result.order.order_nsu, "transaction_nsu" => "fake-1" },
        client: client
      ).call

      expect(webhook).to include(success: true, reason: :processed)
      expect(result.order.reload).to be_paid
      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
    end
  end
end

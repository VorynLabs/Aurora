require "rails_helper"

RSpec.describe "Checkout simulado", type: :request do
  let(:variant) do
    create(:variant, price_cents: 4_990, quantity: 5, reserved: 2,
           product: create(:product, title: "Camisola de cetim"))
  end
  let(:order) { create(:order, status: :pending, total_cents: 9_980) }

  before do
    create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990)

    # A suíte roda com o modo fake desligado; esta página só existe com ele ligado.
    allow(InfinitepayClient).to receive(:fake_enabled?).and_return(true)
  end

  describe "GET /dev/fake_checkout" do
    it "mostra o pedido" do
      get dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(order.order_nsu)
      expect(response.body).to include("Camisola de cetim")
      expect(response.body).to include("R$ 99,80")
    end

    it "oferece os dois desfechos" do
      get dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(response.body).to include("Simular pagamento aprovado")
      expect(response.body).to include("Simular pagamento recusado")
    end

    it "avisa que é ferramenta de desenvolvimento" do
      get dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(response.body).to include("Ferramenta de desenvolvimento")
    end

    it "responde 404 para pedido que não existe" do
      get dev_fake_checkout_path(order_nsu: "ord_nao_existe")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "pagamento aprovado" do
    def approve = post approve_dev_fake_checkout_path(order_nsu: order.order_nsu)

    it "deixa o pedido pago" do
      approve

      expect(order.reload).to be_paid
    end

    it "dá baixa no estoque antes de responder" do
      approve

      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
    end

    it "leva à tela de sucesso que já existe" do
      approve

      expect(response).to redirect_to(checkout_success_path)
    end

    it "registra o evento, como um webhook de verdade" do
      expect { approve }.to change(WebhookEvent, :count).by(1)

      expect(WebhookEvent.sole).to be_processed
    end

    it "usa um transaction_nsu novo a cada clique" do
      approve
      post approve_dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(WebhookEvent.pluck(:event_id).uniq.size).to eq(2)
    end

    it "não baixa o estoque duas vezes em dois cliques" do
      approve
      post approve_dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(variant.reload.quantity).to eq(3)
    end

    it "não toca na rede" do
      approve

      expect(WebMock).not_to have_requested(:post, /infinitepay\.io/)
    end
  end

  describe "pagamento recusado" do
    def decline = post decline_dev_fake_checkout_path(order_nsu: order.order_nsu)

    it "mantém o pedido pendente" do
      decline

      expect(order.reload).to be_pending
    end

    it "não mexe no estoque nem na reserva" do
      decline

      expect(variant.reload).to have_attributes(quantity: 5, reserved: 2)
    end

    it "volta ao carrinho com o aviso" do
      decline

      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to include("Pagamento não concluído")
    end

    it "não registra webhook nenhum" do
      expect { decline }.not_to change(WebhookEvent, :count)
    end
  end

  describe "fora do modo fake" do
    before { allow(InfinitepayClient).to receive(:fake_enabled?).and_return(false) }

    it "a página some" do
      get dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(response).to have_http_status(:not_found)
    end

    it "aprovar não faz nada" do
      post approve_dev_fake_checkout_path(order_nsu: order.order_nsu)

      expect(response).to have_http_status(:not_found)
      expect(order.reload).to be_pending
    end
  end
end

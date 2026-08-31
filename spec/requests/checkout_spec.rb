require "rails_helper"

RSpec.describe "Checkout", type: :request do
  let(:links_url) { "https://api.checkout.infinitepay.io/links" }
  let(:payment_url) { "https://checkout.infinitepay.com.br/aurora_test?lenc=abc123" }
  let(:variant) { create(:variant, quantity: 10, reserved: 0, price_cents: 4_990) }

  def stub_links(status: 200, body: { "url" => payment_url })
    stub_request(:post, links_url).to_return(
      status: status, body: body.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  def fill_cart(quantity: 2)
    post cart_items_path, params: { variant_id: variant.id, quantity: quantity }
  end

  describe "GET /checkout" do
    it "mostra o resumo e as opções de entrega" do
      fill_cart

      get checkout_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(variant.product.title, "R$ 99,80")
      expect(response.body).to include("Retirada no local", "Envio por aplicativo")
      expect(response.body).to include("Pagamento seguro")
    end

    it "traz a nota de embalagem discreta preparada, escondida" do
      fill_cart

      get checkout_path

      expect(response.body).to include("embalagem discreta")
      expect(response.body).to include('data-delivery-target="note" hidden')
    end

    it "volta ao carrinho quando não há nada para comprar" do
      get checkout_path

      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to match(/vazio/)
    end

    it "aceita um item avulso, sem passar pelo carrinho da sessão" do
      get checkout_path(variant_id: variant.id, quantity: 3)

      expect(response.body).to include("R$ 149,70")
      expect(session[:cart]).to be_blank
    end
  end

  describe "POST /checkout" do
    it "abre o pedido, reserva o estoque e manda para a InfinitePay" do
      stub_links
      fill_cart

      expect { post checkout_path }
        .to change(Order, :count).by(1)
        .and change { variant.reload.reserved }.from(0).to(2)

      expect(response).to redirect_to(payment_url)
    end

    it "não baixa o estoque físico" do
      stub_links
      fill_cart

      expect { post checkout_path }.not_to change { variant.reload.quantity }
    end

    it "guarda o link no pedido" do
      stub_links
      fill_cart

      post checkout_path

      expect(Order.last.payment_link_url).to eq(payment_url)
    end

    it "compra direta usa só o item recebido" do
      stub_links
      outra = create(:variant, quantity: 5)
      post cart_items_path, params: { variant_id: outra.id, quantity: 1 }

      post checkout_path, params: { variant_id: variant.id, quantity: 1 }

      expect(Order.last.order_items.pluck(:variant_id)).to eq([variant.id])
      expect(outra.reload.reserved).to eq(0)
    end

    it "volta ao carrinho com aviso quando falta estoque" do
      stub_links
      fill_cart
      variant.update!(quantity: 1)

      expect { post checkout_path }.not_to change(Order, :count)

      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to match(/Sem estoque/)
    end

    it "volta ao carrinho com aviso quando a InfinitePay falha" do
      stub_links(status: 500, body: {})
      fill_cart

      post checkout_path

      expect(response).to redirect_to(cart_path)
      expect(flash[:alert]).to match(/Tente de novo/)
    end

    it "mantém o carrinho da sessão até o cliente chegar ao retorno" do
      stub_links
      fill_cart

      post checkout_path

      expect(session[:cart]).to be_present
    end
  end

  describe "GET /checkout/success" do
    it "diz que o pedido está aguardando confirmação" do
      get checkout_success_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recebemos seu pedido", "aguardando a confirmação")
    end

    it "NÃO toca em estoque nem em reserva" do
      stub_links
      fill_cart
      post checkout_path

      expect { get checkout_success_path }
        .to not_change { variant.reload.quantity }
        .and not_change { variant.reload.reserved }
    end

    it "não marca o pedido como pago" do
      stub_links
      fill_cart
      post checkout_path

      get checkout_success_path

      expect(Order.last).to be_pending
      expect(Order.last.paid_at).to be_nil
    end

    it "esvazia o carrinho da sessão" do
      stub_links
      fill_cart
      post checkout_path

      get checkout_success_path

      expect(session[:cart]).to be_blank
    end
  end
end

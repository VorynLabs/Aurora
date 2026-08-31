require "rails_helper"

RSpec.describe "Carrinho", type: :request do
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:variant) { create(:variant, price_cents: 4_990, quantity: 10) }

  describe "GET /cart" do
    it "abre sem login" do
      get cart_path

      expect(response).to have_http_status(:ok)
    end

    it "convida ao catálogo quando está vazio" do
      get cart_path

      expect(response.body).to include("Seu carrinho está vazio")
    end
  end

  describe "POST /cart/items" do
    it "coloca a variação no carrinho" do
      post cart_items_path, params: { variant_id: variant.id, quantity: 2 }

      get cart_path
      expect(response.body).to include(variant.product.title, "R$ 99,80")
    end

    it "acumula quando a mesma variação entra de novo" do
      post cart_items_path, params: { variant_id: variant.id, quantity: 2 }
      post cart_items_path, params: { variant_id: variant.id, quantity: 3 }

      get cart_path
      expect(response.body).to include("(5 × R$ 49,90)")
    end

    it "redesenha o carrinho do cabeçalho por turbo_stream" do
      post cart_items_path, params: { variant_id: variant.id, quantity: 2 }, headers: turbo

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="replace" target="mini_cart"')
      expect(response.body).to include('action="replace" target="cart_body"')
    end

    it "leva de volta ao carrinho quando o pedido não é turbo" do
      post cart_items_path, params: { variant_id: variant.id, quantity: 1 }

      expect(response).to redirect_to(cart_path)
    end

    it "ignora quantidade não positiva" do
      post cart_items_path, params: { variant_id: variant.id, quantity: 0 }

      get cart_path
      expect(response.body).to include("Seu carrinho está vazio")
    end
  end

  describe "PATCH /cart/items/:id" do
    before { post cart_items_path, params: { variant_id: variant.id, quantity: 5 } }

    it "troca a quantidade em vez de somar" do
      patch cart_item_path(variant), params: { quantity: 2 }

      get cart_path
      expect(response.body).to include("(2 × R$ 49,90)")
    end

    it "tira o item quando a quantidade vai a zero" do
      patch cart_item_path(variant), params: { quantity: 0 }

      get cart_path
      expect(response.body).to include("Seu carrinho está vazio")
    end

    it "redesenha cabeçalho e página por turbo_stream" do
      patch cart_item_path(variant), params: { quantity: 2 }, headers: turbo

      expect(response.body).to include('action="replace" target="mini_cart"')
      expect(response.body).to include('action="replace" target="cart_body"')
      expect(response.body).to include('data-cart-count="2"')
    end
  end

  describe "DELETE /cart/items/:id" do
    it "tira a linha do carrinho" do
      post cart_items_path, params: { variant_id: variant.id, quantity: 2 }

      delete cart_item_path(variant)

      get cart_path
      expect(response.body).to include("Seu carrinho está vazio")
    end

    it "deixa as outras linhas de pé" do
      # Títulos distintos: a fábrica de produto usa o mesmo para todos.
      removida = create(:variant, quantity: 4, product: create(:product, title: "Camisola de cetim"))
      mantida = create(:variant, quantity: 4, product: create(:product, title: "Cinta-liga"))
      post cart_items_path, params: { variant_id: removida.id, quantity: 1 }
      post cart_items_path, params: { variant_id: mantida.id, quantity: 1 }

      delete cart_item_path(removida)

      get cart_path
      expect(response.body).to include("Cinta-liga")
      expect(response.body).not_to include("Camisola de cetim")
    end
  end

  it "avisa quando um item do carrinho ficou sem estoque" do
    post cart_items_path, params: { variant_id: variant.id, quantity: 2 }
    variant.update!(quantity: 0)

    get cart_path

    expect(response.body).to include("ficou sem estoque")
  end

  it "mostra o contador do cabeçalho em todas as telas públicas" do
    post cart_items_path, params: { variant_id: variant.id, quantity: 3 }

    get root_path

    expect(response.body).to include('id="mini_cart"')
    expect(response.body).to include('data-cart-count="3"')
  end
end

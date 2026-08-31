require "rails_helper"

RSpec.describe "Detalhe do produto", type: :request do
  it "abre sem login" do
    product = create(:product, title: "Camisola de cetim")

    get product_path(product)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Camisola de cetim")
  end

  it "mostra imagem, categoria, preço e descrição" do
    categoria = create(:category, name: "Roupas")
    product = create(:product, category: categoria, description: "Cetim leve, alça fina",
                     variant_quantity: 3, variant_price_cents: 12_990)

    get product_path(product)

    expect(response.body).to include("Roupas", "Cetim leve, alça fina", "R$ 129,90")
  end

  it "mostra o menor preço entre as variações disponíveis" do
    product = create(:product, variant_quantity: 2, variant_price_cents: 9_990)
    create(:variant, product: product, quantity: 2, price_cents: 4_990)

    get product_path(product)

    expect(response.body).to include("R$ 49,90")
  end

  describe "produto que o catálogo não mostra" do
    it "responde 404 para produto ocultado pelo admin" do
      product = create(:product, hidden_by_admin: true, variant_quantity: 5)

      get product_path(product)

      expect(response).to have_http_status(:not_found)
    end

    it "responde 404 para produto sem estoque" do
      product = create(:product, variant_quantity: 0)

      get product_path(product)

      expect(response).to have_http_status(:not_found)
    end

    it "responde 404 para produto com o estoque todo reservado" do
      product = create(:product, variant_quantity: 5, variant_reserved: 5)

      get product_path(product)

      expect(response).to have_http_status(:not_found)
    end

    it "responde 404 para produto que não existe" do
      get product_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "bloco de compra" do
    it "traz o seletor de quantidade preso ao estoque da variação" do
      product = create(:product, variant_quantity: 3)

      get product_path(product)

      expect(response.body).to include('data-stepper-max-value="3"')
    end

    it "desconta o que já está reservado no teto do estoque" do
      product = create(:product, variant_quantity: 10, variant_reserved: 7)

      get product_path(product)

      expect(response.body).to include('data-stepper-max-value="3"')
    end

    it "oferece o seletor quando há mais de uma variação disponível" do
      product = create(:product, variant_quantity: 2)
      create(:variant, product: product, name: "Preta / M", quantity: 4)

      get product_path(product)

      expect(response.body).to include("Preta / M")
      expect(response.body).to include('data-variant-picker-target="select"')
    end

    it "não oferece seletor quando só há uma variação" do
      create(:product, variant_quantity: 2)

      get product_path(Product.last)

      expect(response.body).not_to include('data-variant-picker-target="select"')
    end

    it "esconde do seletor a variação sem estoque" do
      product = create(:product, variant_quantity: 2)
      create(:variant, product: product, name: "Esgotada", quantity: 0)

      get product_path(product)

      expect(response.body).not_to include("Esgotada")
    end

    it "leva os dois botões de compra e o selo de pagamento" do
      create(:product)

      get product_path(Product.last)

      expect(response.body).to include("Adicionar ao carrinho", "Comprar agora", "Pagamento seguro")
    end

    it "aponta os botões para as rotas de carrinho e checkout" do
      create(:product)

      get product_path(Product.last)

      expect(response.body).to include(%(action="/cart/items"))
      expect(response.body).to include(%(formaction="/checkout"))
    end
  end

  it "é alcançável a partir do card do catálogo" do
    product = create(:product, title: "Camisola de cetim")

    get root_path

    expect(response.body).to include(%(href="#{product_path(product)}"))
  end
end

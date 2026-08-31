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

  it "é alcançável a partir do card do catálogo" do
    product = create(:product, title: "Camisola de cetim")

    get root_path

    expect(response.body).to include(%(href="#{product_path(product)}"))
  end
end

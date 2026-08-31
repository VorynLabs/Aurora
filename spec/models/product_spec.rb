require "rails_helper"

RSpec.describe Product, type: :model do
  describe "validações" do
    it "é inválido sem título" do
      product = build(:product, title: nil)

      expect(product).not_to be_valid
      expect(product.errors[:title]).to be_present
    end

    it "é inválido sem ao menos uma variação" do
      product = build(:product)
      product.variants = []

      expect(product).not_to be_valid
      expect(product.errors[:base]).to include("produto precisa de ao menos uma variação")
    end

    it "é inválido quando a última variação está marcada para remoção" do
      product = create(:product)
      product.variants.first.mark_for_destruction

      expect(product).not_to be_valid
      expect(product.errors[:base]).to include("produto precisa de ao menos uma variação")
    end
  end

  # Tabela canônica do SPEC 01. O scope (SQL) e o predicado (memória) precisam
  # concordar em todos os casos, então cada um é verificado nos dois caminhos.
  describe "regra de visibilidade no catálogo" do
    it "exclui produto ocultado manualmente, mesmo com estoque" do
      product = create(:product, hidden_by_admin: true, variant_quantity: 5)

      expect(Product.visible_in_catalog).not_to include(product)
      expect(product).not_to be_visible_in_catalog
    end

    it "exclui produto com todas as variações zeradas" do
      product = create(:product, variant_quantity: 0)

      expect(Product.visible_in_catalog).not_to include(product)
      expect(product).not_to be_visible_in_catalog
    end

    it "inclui produto com ao menos uma variação disponível" do
      product = create(:product, variant_quantity: 1)

      expect(Product.visible_in_catalog).to include(product)
      expect(product).to be_visible_in_catalog
    end

    it "exclui produto cujo estoque está todo reservado" do
      product = create(:product, variant_quantity: 5, variant_reserved: 5)

      expect(Product.visible_in_catalog).not_to include(product)
      expect(product).not_to be_visible_in_catalog
    end

    it "mantém o produto quando só uma das variações zera" do
      product = create(:product, variant_quantity: 0)
      create(:variant, product: product, quantity: 3)
      product.reload

      expect(Product.visible_in_catalog).to include(product)
      expect(product).to be_visible_in_catalog
      expect(product.variants.available.count).to eq(1)
    end

    it "não repete o produto que tem várias variações disponíveis" do
      product = create(:product, variant_quantity: 2)
      create(:variant, product: product, quantity: 3)

      expect(Product.visible_in_catalog.to_a.count(product)).to eq(1)
    end
  end

  describe "#min_price_cents" do
    it "retorna o menor preço entre as variações disponíveis" do
      product = create(:product, variant_quantity: 5, variant_price_cents: 4_990)
      create(:variant, product: product, quantity: 5, price_cents: 3_990)
      create(:variant, product: product, quantity: 5, price_cents: 7_990)

      expect(product.min_price_cents).to eq(3_990)
    end

    it "ignora variações sem estoque disponível" do
      product = create(:product, variant_quantity: 5, variant_price_cents: 4_990)
      create(:variant, product: product, quantity: 0, price_cents: 1_990)

      expect(product.min_price_cents).to eq(4_990)
    end

    it "cai para o menor preço geral quando nenhuma variação está disponível" do
      product = create(:product, variant_quantity: 0, variant_price_cents: 4_990)
      create(:variant, product: product, quantity: 0, price_cents: 1_990)

      expect(product.min_price_cents).to eq(1_990)
    end
  end

  describe "associações" do
    it "remove as variações junto com o produto" do
      product = create(:product)

      expect { product.destroy }.to change(Variant, :count).by(-1)
    end
  end
end

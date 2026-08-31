require "rails_helper"

RSpec.describe Variant, type: :model do
  describe "#available_stock" do
    it "é o estoque físico menos o que está reservado" do
      variant = build(:variant, quantity: 10, reserved: 3)

      expect(variant.available_stock).to eq(7)
    end
  end

  describe ".available" do
    it "traz só as variações com pelo menos uma unidade disponível" do
      # O produto nasce com uma variação própria; deixá-la zerada mantém o
      # scope global restrito às variações montadas aqui.
      product = create(:product, variant_quantity: 0)
      disponivel = create(:variant, product: product, quantity: 1, reserved: 0)
      create(:variant, product: product, quantity: 0, reserved: 0)
      create(:variant, product: product, quantity: 5, reserved: 5)

      expect(product.variants.available).to contain_exactly(disponivel)
    end
  end

  describe "validações" do
    it "é inválida sem nome" do
      variant = build(:variant, name: nil)

      expect(variant).not_to be_valid
      expect(variant.errors[:name]).to be_present
    end

    it "rejeita quantidade negativa" do
      variant = build(:variant, quantity: -1)

      expect(variant).not_to be_valid
      expect(variant.errors[:quantity]).to be_present
    end

    it "rejeita reserva negativa" do
      variant = build(:variant, reserved: -1)

      expect(variant).not_to be_valid
      expect(variant.errors[:reserved]).to be_present
    end

    it "rejeita preço negativo" do
      variant = build(:variant, price_cents: -1)

      expect(variant).not_to be_valid
      expect(variant.errors[:price_cents]).to be_present
    end
  end

  describe "helpers de dinheiro" do
    it "converte centavos em reais" do
      expect(build(:variant, price_cents: 4_990).price).to eq(49.90)
    end

    it "formata o preço no padrão brasileiro" do
      expect(build(:variant, price_cents: 4_990).price_brl).to eq("R$ 49,90")
    end

    it "formata valores redondos com as duas casas decimais" do
      expect(build(:variant, price_cents: 10_000).price_brl).to eq("R$ 100,00")
    end
  end

  describe "#price_reais" do
    it "mostra o preço guardado no formato que o admin digita" do
      expect(build(:variant, price_cents: 4_990).price_reais).to eq("49,90")
    end

    it "é nil enquanto não há preço" do
      expect(Variant.new.price_reais).to be_nil
    end

    it "devolve o que foi digitado, mesmo quando não dá para converter" do
      variant = build(:variant, price_reais: "quarenta")

      expect(variant.price_reais).to eq("quarenta")
    end
  end

  describe "#price_reais=" do
    {
      "49,90" => 4_990,
      "49.90" => 4_990,
      "R$ 49,90" => 4_990,
      " 49,90 " => 4_990,
      "1.234,56" => 123_456,
      "1.234" => 123_400,
      "100" => 10_000,
      "0,05" => 5
    }.each do |entrada, centavos|
      it "converte #{entrada.inspect} em #{centavos} centavos" do
        expect(build(:variant, price_reais: entrada).price_cents).to eq(centavos)
      end
    end

    it "não perde centavo por arredondamento de float" do
      expect(build(:variant, price_reais: "1.234,45").price_cents).to eq(123_445)
    end

    it "zera o preço quando o campo vem vazio, e a validação reclama" do
      variant = build(:variant, price_reais: "")

      expect(variant.price_cents).to be_nil
      expect(variant).not_to be_valid
      expect(variant.errors[:price_cents]).to be_present
    end

    it "recusa texto que não é número" do
      variant = build(:variant, price_reais: "quarenta reais")

      expect(variant.price_cents).to be_nil
      expect(variant).not_to be_valid
    end
  end
end

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

      expect(Variant.available).to contain_exactly(disponivel)
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
end

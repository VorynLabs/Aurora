require "rails_helper"

RSpec.describe Category, type: :model do
  it "é inválida sem nome" do
    category = build(:category, name: nil)

    expect(category).not_to be_valid
    expect(category.errors[:name]).to be_present
  end

  it "gera o slug a partir do nome quando ele não é informado" do
    category = create(:category, name: "Roupas Íntimas")

    expect(category.slug).to eq("roupas-intimas")
  end

  it "mantém o slug informado explicitamente" do
    category = create(:category, name: "Roupas", slug: "lingerie")

    expect(category.slug).to eq("lingerie")
  end

  it "rejeita slug duplicado" do
    existente = create(:category)
    duplicate = build(:category, slug: existente.slug)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to be_present
  end

  describe ".ordered" do
    it "ordena por posição e depois por nome" do
      terceira = create(:category, name: "Vestidos", position: 2)
      primeira = create(:category, name: "Acessórios", position: 1)
      segunda = create(:category, name: "Bolsas", position: 2)

      ordenadas = Category.ordered.where(id: [terceira.id, primeira.id, segunda.id])

      expect(ordenadas).to eq([primeira, segunda, terceira])
    end
  end
end

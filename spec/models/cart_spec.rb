require "rails_helper"

RSpec.describe Cart do
  subject(:cart) { described_class.new({}) }

  let(:variant) { create(:variant, price_cents: 4_990) }
  let(:outra) { create(:variant, price_cents: 12_990) }

  describe "#add" do
    it "guarda a variação com a quantidade pedida" do
      cart.add(variant.id, 2)

      expect(cart.line_items).to contain_exactly(hash_including(variant: variant, quantity: 2))
    end

    it "acumula quando a mesma variação entra de novo" do
      cart.add(variant.id, 2)
      cart.add(variant.id, 3)

      expect(cart.line_items.sole[:quantity]).to eq(5)
    end

    it "trata id em string e em inteiro como a mesma variação" do
      cart.add(variant.id, 1)
      cart.add(variant.id.to_s, 1)

      expect(cart.line_items.size).to eq(1)
      expect(cart.line_items.sole[:quantity]).to eq(2)
    end

    it "ignora quantidade zero ou negativa" do
      cart.add(variant.id, 0)
      cart.add(variant.id, -3)

      expect(cart).to be_empty
    end
  end

  describe "#set" do
    it "troca a quantidade em vez de somar" do
      cart.add(variant.id, 5)

      cart.set(variant.id, 2)

      expect(cart.line_items.sole[:quantity]).to eq(2)
    end

    it "remove o item quando a quantidade vira zero" do
      cart.add(variant.id, 5)

      cart.set(variant.id, 0)

      expect(cart).to be_empty
    end

    it "remove o item quando a quantidade fica negativa" do
      cart.add(variant.id, 5)

      cart.set(variant.id, -1)

      expect(cart).to be_empty
    end
  end

  describe "#remove" do
    it "tira a variação do carrinho" do
      cart.add(variant.id, 1)
      cart.add(outra.id, 1)

      cart.remove(variant.id)

      expect(cart.line_items).to contain_exactly(hash_including(variant: outra))
    end
  end

  describe "#line_items" do
    it "mantém a ordem em que os itens entraram" do
      cart.add(outra.id, 1)
      cart.add(variant.id, 1)

      expect(cart.line_items.map { _1[:variant] }).to eq([outra, variant])
    end

    it "ignora variação que não existe mais" do
      cart.add(variant.id, 1)
      cart.add(outra.id, 1)
      outra.destroy!

      expect(cart.line_items).to contain_exactly(hash_including(variant: variant))
    end
  end

  describe "#total_cents" do
    it "soma preço vezes quantidade de cada linha" do
      cart.add(variant.id, 2)   # 2 x 49,90
      cart.add(outra.id, 1)     # 1 x 129,90

      expect(cart.total_cents).to eq(22_970)
    end

    it "é zero no carrinho vazio" do
      expect(cart.total_cents).to eq(0)
    end

    it "acompanha a mudança de preço da variação" do
      cart.add(variant.id, 1)

      variant.update!(price_cents: 1_000)

      expect(cart.total_cents).to eq(1_000)
    end
  end

  describe "#count" do
    it "soma as unidades, não as linhas" do
      cart.add(variant.id, 2)
      cart.add(outra.id, 3)

      expect(cart.count).to eq(5)
    end
  end

  describe ".ephemeral" do
    it "nasce com um único item e fora da sessão" do
      session = {}
      ephemeral = described_class.ephemeral(variant.id, 2)

      expect(ephemeral.line_items).to contain_exactly(hash_including(variant: variant, quantity: 2))
      expect(session).to be_empty
    end
  end

  describe "sobre a sessão" do
    it "escreve no store que recebeu" do
      session = {}

      described_class.new(session).add(variant.id, 2)

      expect(session[:cart]).to eq({ variant.id.to_s => 2 })
    end

    it "lê o que já estava lá" do
      session = { cart: { variant.id.to_s => 4 } }

      expect(described_class.new(session).line_items.sole[:quantity]).to eq(4)
    end
  end
end

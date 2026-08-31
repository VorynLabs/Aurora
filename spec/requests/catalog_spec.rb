require "rails_helper"

RSpec.describe "Catálogo público", type: :request do
  it "abre sem login" do
    get root_path

    expect(response).to have_http_status(:ok)
  end

  describe "o que aparece na listagem" do
    it "mostra produto com variação disponível" do
      create(:product, title: "Camisola de cetim", variant_quantity: 2)

      get root_path

      expect(response.body).to include("Camisola de cetim")
    end

    it "esconde produto ocultado pelo admin" do
      create(:product, title: "Escondido", hidden_by_admin: true, variant_quantity: 5)

      get root_path

      expect(response.body).not_to include("Escondido")
    end

    it "esconde produto sem estoque" do
      create(:product, title: "Zerado", variant_quantity: 0)

      get root_path

      expect(response.body).not_to include("Zerado")
    end

    it "esconde produto com o estoque todo reservado" do
      create(:product, title: "Reservado", variant_quantity: 5, variant_reserved: 5)

      get root_path

      expect(response.body).not_to include("Reservado")
    end

    it "não repete o produto que tem várias variações disponíveis" do
      product = create(:product, title: "Camisola de cetim", variant_quantity: 2)
      create(:variant, product: product, quantity: 3)

      get root_path

      expect(response.body.scan("Camisola de cetim").size).to eq(1)
    end
  end

  describe "o card" do
    it "mostra o menor preço entre as variações disponíveis" do
      product = create(:product, variant_quantity: 5, variant_price_cents: 9_990)
      create(:variant, product: product, quantity: 5, price_cents: 4_990)

      get root_path

      expect(response.body).to include("R$ 49,90")
      expect(response.body).not_to include("R$ 99,90")
    end

    it "ignora o preço de variação sem estoque" do
      product = create(:product, variant_quantity: 5, variant_price_cents: 9_990)
      create(:variant, product: product, quantity: 0, price_cents: 1_990)

      get root_path

      expect(response.body).to include("R$ 99,90")
      expect(response.body).not_to include("R$ 19,90")
    end

    it "avisa quando o estoque está acabando" do
      create(:product, title: "Quase lá", variant_quantity: 2)

      get root_path

      expect(response.body).to include("Últimas unidades")
    end

    it "não avisa quando há estoque de sobra" do
      create(:product, title: "Cheio", variant_quantity: 20)

      get root_path

      expect(response.body).not_to include("Últimas unidades")
    end
  end

  describe "filtro por categoria" do
    let!(:roupas) { create(:category, name: "Roupas") }
    let!(:acessorios) { create(:category, name: "Acessórios") }

    before do
      create(:product, title: "Camisola de cetim", category: roupas)
      create(:product, title: "Cinta-liga", category: acessorios)
    end

    it "restringe a lista à categoria escolhida" do
      get root_path(category_id: roupas.id)

      expect(response.body).to include("Camisola de cetim")
      expect(response.body).not_to include("Cinta-liga")
    end

    it "lista tudo sem categoria" do
      get root_path

      expect(response.body).to include("Camisola de cetim", "Cinta-liga")
    end

    it "não deixa a categoria furar a regra de visibilidade" do
      create(:product, title: "Oculto", category: roupas, hidden_by_admin: true)

      get root_path(category_id: roupas.id)

      expect(response.body).not_to include("Oculto")
    end

    it "avisa quando a categoria não tem nada visível" do
      vazia = create(:category, name: "Vazia")

      get root_path(category_id: vazia.id)

      expect(response.body).to include("Nada por aqui ainda")
    end
  end

  it "convida a voltar quando não há nada visível" do
    get root_path

    expect(response.body).to include("Nada por aqui ainda")
  end
end

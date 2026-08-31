require "rails_helper"

RSpec.describe "Detalhe do produto", type: :system do
  let(:product) { create(:product, title: "Camisola de cetim", variant_quantity: 3) }

  # Sobe a quantidade até o stepper travar. Contar cliques não serve: o botão
  # desabilita ao encostar no estoque, e o clique seguinte falharia.
  def raise_quantity_to_the_top
    while (button = first("button[aria-label='Aumentar quantidade']:not([disabled])",
                          minimum: 0, wait: 0.5))
      button.click
    end
  end

  describe "seletor de quantidade" do
    it "não deixa passar do estoque disponível" do
      visit product_path(product)

      raise_quantity_to_the_top

      expect(page).to have_field("Quantidade", with: "3")
      expect(page).to have_button("Aumentar quantidade", disabled: true)
    end

    it "não desce abaixo de uma unidade" do
      visit product_path(product)

      expect(page).to have_field("Quantidade", with: "1")
      expect(page).to have_button("Diminuir quantidade", disabled: true)

      click_button "Aumentar quantidade"
      click_button "Diminuir quantidade"

      expect(page).to have_field("Quantidade", with: "1")
      expect(page).to have_button("Diminuir quantidade", disabled: true)
    end

    it "corrige um valor digitado acima do estoque" do
      visit product_path(product)

      fill_in "Quantidade", with: "99"
      find_field("Quantidade").send_keys(:tab)

      expect(page).to have_field("Quantidade", with: "3")
    end

    it "desconta o que já está reservado" do
      reservado = create(:product, title: "Quase esgotada", variant_quantity: 10, variant_reserved: 8)

      visit product_path(reservado)

      raise_quantity_to_the_top

      expect(page).to have_field("Quantidade", with: "2")
    end
  end

  describe "seletor de variação" do
    let!(:product) { create(:product, title: "Camisola", variant_quantity: 3, variant_price_cents: 9_990) }
    let!(:outra) do
      create(:variant, product: product, name: "Preta / M", quantity: 7, price_cents: 12_990)
    end

    it "troca preço e estoque exibidos" do
      visit product_path(product)

      expect(page).to have_content("R$ 99,90")
      expect(page).to have_content("3 unidades disponíveis")

      select "Preta / M", from: "Variação"

      expect(page).to have_content("R$ 129,90")
      expect(page).to have_content("7 unidades disponíveis")
    end

    it "move o teto do estoque junto com a variação escolhida" do
      visit product_path(product)

      select "Preta / M", from: "Variação"
      raise_quantity_to_the_top

      expect(page).to have_field("Quantidade", with: "7")
    end

    it "baixa a quantidade quando a nova variação tem menos estoque" do
      visit product_path(product)

      select "Preta / M", from: "Variação"
      raise_quantity_to_the_top
      expect(page).to have_field("Quantidade", with: "7")

      select product.variants.order(:price_cents).first.name, from: "Variação"

      expect(page).to have_field("Quantidade", with: "3")
    end
  end

  describe "produtos que o catálogo não mostra" do
    it "não oferecem link no catálogo" do
      create(:product, title: "Escondido", hidden_by_admin: true, variant_quantity: 5)
      create(:product, title: "Zerado", variant_quantity: 0)

      visit root_path

      expect(page).to have_no_content("Escondido")
      expect(page).to have_no_content("Zerado")
    end
  end

  it "busca a partir do detalhe volta para o catálogo" do
    create(:product, title: "Cinta-liga")
    visit product_path(product)

    fill_in "Buscar produtos", with: "cinta"

    expect(page).to have_current_path(/\?q=cinta/)
    expect(page).to have_content("Cinta-liga")
  end
end

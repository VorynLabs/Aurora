require "rails_helper"

RSpec.describe "Carrinho", type: :system do
  let!(:product) { create(:product, title: "Camisola de cetim", variant_quantity: 8, variant_price_cents: 4_990) }
  let(:variant) { product.variants.first }

  def cart_count
    find("[data-cart-count]")["data-cart-count"]
  end

  it "adiciona do detalhe do produto e atualiza o contador sem recarregar" do
    visit product_path(product)

    expect(cart_count).to eq("0")
    page.execute_script("window.semReload = true")

    click_button "Aumentar quantidade"
    click_button "Adicionar ao carrinho"

    expect(page).to have_selector("[data-cart-count='2']")
    expect(page.evaluate_script("window.semReload")).to be(true)
  end

  it "lista o item no mini-carrinho do cabeçalho" do
    visit product_path(product)
    click_button "Adicionar ao carrinho"

    expect(page).to have_selector("[data-cart-count='1']")

    click_button "Carrinho"

    within "#mini_cart" do
      expect(page).to have_content("Camisola de cetim")
      expect(page).to have_content("R$ 49,90")
      expect(page).to have_link("Ver carrinho")
    end
  end

  it "muda a quantidade na página do carrinho e o total acompanha" do
    visit product_path(product)
    click_button "Adicionar ao carrinho"
    expect(page).to have_selector("[data-cart-count='1']")

    visit cart_path
    expect(page).to have_content("R$ 49,90")

    click_button "Aumentar quantidade"

    expect(page).to have_content("R$ 99,80")
    expect(page).to have_selector("[data-cart-count='2']")
  end

  it "remove a linha e volta ao carrinho vazio" do
    visit product_path(product)
    click_button "Adicionar ao carrinho"
    expect(page).to have_selector("[data-cart-count='1']")

    visit cart_path
    click_button "Remover"

    expect(page).to have_content("Seu carrinho está vazio")
    expect(page).to have_selector("[data-cart-count='0']")
  end

  it "não deixa pedir mais unidades do que há em estoque" do
    variant.update!(quantity: 2)
    visit product_path(product)
    click_button "Adicionar ao carrinho"
    expect(page).to have_selector("[data-cart-count='1']")

    visit cart_path
    click_button "Aumentar quantidade"

    expect(page).to have_selector("[data-cart-count='2']")
    expect(page).to have_button("Aumentar quantidade", disabled: true)
  end
end

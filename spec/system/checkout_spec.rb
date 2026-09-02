require "rails_helper"

RSpec.describe "Checkout", type: :system do
  let!(:product) { create(:product, title: "Camisola de cetim", variant_quantity: 5, variant_price_cents: 4_990) }
  let(:payment_url) { "https://checkout.infinitepay.com.br/aurora_test?lenc=abc123" }

  before do
    stub_request(:post, "https://api.checkout.infinitepay.io/links").to_return(
      status: 200, body: { url: payment_url }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  it "mostra a nota de embalagem discreta só no fluxo de envio" do
    visit product_path(product)
    click_button "Comprar agora"

    expect(page).to have_content("Finalizar compra")
    expect(page).to have_no_content("embalagem discreta")

    choose "Envio por aplicativo, pago por você"

    expect(page).to have_content("embalagem discreta")

    choose "Retirada no local"

    expect(page).to have_no_content("embalagem discreta")
  end

  it "leva o item do 'Comprar agora' direto para o checkout" do
    visit product_path(product)
    click_button "Aumentar quantidade"
    click_button "Comprar agora"

    expect(page).to have_content("Camisola de cetim")
    expect(page).to have_content("R$ 99,80")
    expect(page).to have_selector("[data-cart-count='0']")
  end

  it "sai do carrinho para o checkout" do
    visit product_path(product)
    click_button "Adicionar ao carrinho"
    expect(page).to have_selector("[data-cart-count='1']")

    visit cart_path
    click_link "Finalizar compra"

    expect(page).to have_content("Finalizar compra")
    expect(page).to have_content("R$ 49,90")
  end

  it "reserva o estoque ao seguir para o pagamento, sem baixar o físico" do
    variant = product.variants.first

    visit product_path(product) # sobe o servidor de teste

    # O navegador não sai para a internet num spec: o "gateway" devolve uma URL
    # do próprio servidor. O destino de verdade é coberto no request spec.
    stub_request(:post, "https://api.checkout.infinitepay.io/links").to_return(
      status: 200, body: { url: "#{page.server.base_url}/checkout/success" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    click_button "Adicionar ao carrinho"
    expect(page).to have_selector("[data-cart-count='1']")

    visit cart_path
    click_link "Finalizar compra"
    click_button "Ir para o pagamento"

    expect(page).to have_content("Recebemos seu pedido")

    variant.reload
    expect(variant.reserved).to eq(1)
    expect(variant.quantity).to eq(5)
    expect(Order.last).to be_pending
  end
end

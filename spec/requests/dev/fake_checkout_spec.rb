require "rails_helper"

RSpec.describe "Checkout simulado", type: :request do
  let(:variant) { create(:variant, price_cents: 4_990, product: create(:product, title: "Camisola de cetim")) }
  let(:order) { create(:order, total_cents: 9_980) }

  before { create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990) }

  it "mostra o pedido na página de pagamento simulado" do
    get dev_fake_checkout_path(order_nsu: order.order_nsu)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(order.order_nsu)
    expect(response.body).to include("Camisola de cetim")
    expect(response.body).to include("R$ 99,80")
  end

  it "deixa disparar o webhook a partir dela" do
    get dev_fake_checkout_path(order_nsu: order.order_nsu)

    expect(response.body).to include('action="/webhooks/infinitepay"')
    expect(response.body).to include("Simular pagamento aprovado")
  end

  it "responde 404 para pedido que não existe" do
    get dev_fake_checkout_path(order_nsu: "ord_nao_existe")

    expect(response).to have_http_status(:not_found)
  end

  # A rota nem é montada em produção; o filtro no controller é a segunda tranca.
  it "some em produção" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

    get dev_fake_checkout_path(order_nsu: order.order_nsu)

    expect(response).to have_http_status(:not_found)
  end
end

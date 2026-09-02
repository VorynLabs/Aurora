require "rails_helper"

RSpec.describe Payments::CreateCheckout do
  let(:payment_url) { "https://checkout.infinitepay.com.br/aurora_test?lenc=abc123" }
  let(:client) { instance_double(InfinitepayClient, create_link: payment_url) }

  let(:variant) { create(:variant, quantity: 10, reserved: 0, price_cents: 4_990) }

  def cart_with(*pairs)
    Cart.new({}).tap do |cart|
      pairs.each { |variant, quantity| cart.add(variant.id, quantity) }
    end
  end

  def checkout(cart) = described_class.new(cart, client: client).call

  describe "o pedido criado" do
    it "nasce pendente com a reserva vencendo em 7 minutos" do
      result = checkout(cart_with([variant, 2]))

      expect(result).to be_ok
      expect(result.order).to be_pending
      expect(result.order.reserved_until).to be_within(5.seconds).of(7.minutes.from_now)
    end

    it "gera o order_nsu que a conciliação vai usar" do
      result = checkout(cart_with([variant, 1]))

      expect(result.order.order_nsu).to be_present
    end

    it "cria um item por variação, com o preço travado" do
      outra = create(:variant, quantity: 5, price_cents: 12_990)

      result = checkout(cart_with([variant, 2], [outra, 1]))

      expect(result.order.order_items.pluck(:variant_id, :quantity, :price_cents))
        .to contain_exactly([variant.id, 2, 4_990], [outra.id, 1, 12_990])
    end

    it "soma o total em centavos" do
      outra = create(:variant, quantity: 5, price_cents: 12_990)

      result = checkout(cart_with([variant, 2], [outra, 1]))

      expect(result.order.total_cents).to eq(22_970)
    end

    it "guarda o link de pagamento" do
      result = checkout(cart_with([variant, 1]))

      expect(result.payment_url).to eq(payment_url)
      expect(result.order.reload.payment_link_url).to eq(payment_url)
    end
  end

  describe "reserva de estoque" do
    it "aumenta reserved sem tocar em quantity" do
      expect { checkout(cart_with([variant, 3])) }
        .to change { variant.reload.reserved }.from(0).to(3)
        .and not_change { variant.reload.quantity }
    end

    it "soma à reserva que já existia" do
      variant.update!(reserved: 2)

      checkout(cart_with([variant, 3]))

      expect(variant.reload.reserved).to eq(5)
    end

    it "reserva cada variação do carrinho" do
      outra = create(:variant, quantity: 5, reserved: 0)

      checkout(cart_with([variant, 2], [outra, 1]))

      expect(variant.reload.reserved).to eq(2)
      expect(outra.reload.reserved).to eq(1)
    end

    it "trava a linha da variação enquanto reserva" do
      allow(Variant).to receive(:lock).and_call_original

      checkout(cart_with([variant, 1]))

      expect(Variant).to have_received(:lock)
    end
  end

  describe "quando falta estoque" do
    it "recusa quando o pedido é maior que o disponível" do
      variant.update!(quantity: 2)

      result = checkout(cart_with([variant, 3]))

      expect(result).not_to be_ok
      expect(result.error).to match(/Sem estoque/)
    end

    it "conta o que já está reservado como indisponível" do
      variant.update!(quantity: 5, reserved: 5)

      result = checkout(cart_with([variant, 1]))

      expect(result).not_to be_ok
    end

    it "não deixa pedido nem reserva pela metade" do
      disponivel = create(:variant, quantity: 10, reserved: 0)
      esgotada = create(:variant, quantity: 0, reserved: 0)

      expect { checkout(cart_with([disponivel, 1], [esgotada, 1])) }
        .to not_change(Order, :count)
        .and not_change { disponivel.reload.reserved }
    end

    it "nem chega a pedir o link de pagamento" do
      variant.update!(quantity: 0)

      checkout(cart_with([variant, 1]))

      expect(client).not_to have_received(:create_link)
    end
  end

  describe "carrinho vazio" do
    it "recusa sem criar pedido" do
      result = nil

      expect { result = checkout(Cart.new({})) }.not_to change(Order, :count)
      expect(result).not_to be_ok
      expect(result.error).to match(/vazio/)
    end
  end

  describe "quando a InfinitePay falha" do
    let(:client) { instance_double(InfinitepayClient) }

    before { allow(client).to receive(:create_link).and_raise(InfinitepayClient::Error, "500") }

    it "devolve erro sem estourar exceção" do
      result = checkout(cart_with([variant, 1]))

      expect(result).not_to be_ok
      expect(result.error).to match(/Tente de novo/)
    end

    it "deixa o pedido pendente com a reserva de pé, para o job de expiração devolver" do
      result = checkout(cart_with([variant, 1]))

      expect(result.order).to be_pending
      expect(variant.reload.reserved).to eq(1)
    end
  end

  describe "a chamada externa" do
    it "acontece fora da transação, para não segurar os locks na rede" do
      transacoes_fora = ActiveRecord::Base.connection.open_transactions
      transacoes_durante_a_chamada = nil

      allow(client).to receive(:create_link) do
        transacoes_durante_a_chamada = ActiveRecord::Base.connection.open_transactions
        payment_url
      end

      checkout(cart_with([variant, 1]))

      expect(transacoes_durante_a_chamada).to eq(transacoes_fora)
    end
  end
end

module Payments
  # Passos 1 a 4 do SPEC 04: valida estoque, cria o pedido, RESERVA as unidades
  # (sem baixar quantity) e pega o link de pagamento.
  #
  # A baixa definitiva não acontece aqui. Ela só ocorre quando o webhook
  # confirma o pagamento — é esse o ponto do sistema inteiro.
  class CreateCheckout
    Result = Struct.new(:ok?, :order, :payment_url, :error)

    # Sete minutos: tempo de pagar um Pix sem segurar a unidade de quem está
    # olhando o catálogo agora. Anda junto com o ExpireReservationsJob, que roda
    # a cada 2 min — a indisponibilidade real é a soma dos dois.
    RESERVATION_WINDOW = 7.minutes

    class Empty < StandardError; end
    class OutOfStock < StandardError; end

    def initialize(cart, client: InfinitepayClient.new)
      @cart = cart
      @client = client
    end

    def call
      order = reserve

      # Chamada externa FORA da transação: segurar locks de linha esperando a
      # rede da InfinitePay travaria o checkout de todo mundo. Se ela falhar, o
      # pedido fica pendente e o job de expiração devolve a reserva.
      payment_url = @client.create_link(order)
      order.update!(payment_link_url: payment_url)

      Result.new(true, order, payment_url, nil)
    rescue Empty
      Result.new(false, nil, nil, "Seu carrinho está vazio.")
    rescue OutOfStock => e
      Result.new(false, nil, nil, "Sem estoque: #{e.message}")
    rescue InfinitepayClient::Error, Faraday::Error
      Result.new(false, order, nil, "Não foi possível abrir o pagamento agora. Tente de novo em instantes.")
    end

    private

    def reserve
      order = nil

      ActiveRecord::Base.transaction do
        lines = @cart.line_items
        raise Empty if lines.empty?

        order = Order.create!(status: :pending, reserved_until: RESERVATION_WINDOW.from_now)

        # Sempre na mesma ordem de id: dois checkouts com os mesmos itens em
        # ordens diferentes poderiam travar um ao outro.
        lines.sort_by { |line| line[:variant].id }.each do |line|
          reserve_line(order, line)
        end

        order.update!(total_cents: order.order_items.sum { _1.quantity * _1.price_cents })
      end

      order
    end

    def reserve_line(order, line)
      variant = Variant.lock.find(line[:variant].id)
      quantity = line[:quantity]

      if variant.available_stock < quantity
        raise OutOfStock, "#{variant.product.title} — #{variant.name}"
      end

      variant.update!(reserved: variant.reserved + quantity)

      # Preço travado no momento da compra: mudar a tabela depois não mexe
      # em pedido já aberto.
      order.order_items.create!(variant: variant, quantity: quantity,
                                price_cents: variant.price_cents)
    end
  end
end

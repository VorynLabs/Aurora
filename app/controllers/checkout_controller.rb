class CheckoutController < ApplicationController
  layout "catalog"

  def new
    @cart = checkout_cart

    redirect_to cart_path, alert: "Seu carrinho está vazio." if @cart.empty?
  end

  def create
    result = Payments::CreateCheckout.new(checkout_cart).call

    if result.ok?
      # allow_other_host: o pagamento acontece no domínio da InfinitePay.
      redirect_to result.payment_url, allow_other_host: true
    else
      redirect_to cart_path, alert: result.error
    end
  end

  # redirect_url da InfinitePay. Só UX: NÃO confirma pagamento e NÃO toca em
  # estoque. Quem dá baixa é o webhook, no próximo escopo.
  def success
    # O carrinho é esvaziado aqui, e não ao abrir o pedido, para que um
    # pagamento abandonado não custe ao cliente montar tudo de novo.
    session.delete(:cart)
  end

  private

  # "Comprar agora" traz o item pela URL e não passa pelo carrinho da sessão.
  def buy_now? = params[:variant_id].present?

  def checkout_cart
    return Cart.ephemeral(params[:variant_id], params[:quantity]) if buy_now?

    current_cart
  end
end

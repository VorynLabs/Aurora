# Substitui o checkout da InfinitePay quando o modo fake está ligado. Simula os
# dois desfechos possíveis usando os caminhos que o app já tem: nenhuma tela de
# sucesso ou de falha nasce aqui.
#
# Duas trancas, porque uma página que finge pagamento não pode existir onde há
# dinheiro de verdade: a rota não é montada em produção, e nada responde a menos
# que o modo fake esteja ligado.
class Dev::FakeCheckoutController < ApplicationController
  layout "catalog"

  before_action :ensure_fake_mode
  before_action :load_order

  def show; end

  # Aprovado: entrega o mesmo evento que a InfinitePay entregaria e só depois
  # manda o cliente para a tela de sucesso. A ordem importa — a tela não prova
  # pagamento nenhum, quem dá baixa é o webhook, e ele roda antes do redirect.
  #
  # Chama Payments::ProcessWebhook direto em vez de fazer o app postar em si
  # mesmo: é o mesmo objeto que o Webhooks::InfinitepayController chama, com o
  # mesmo payload, e assim o processamento termina antes da resposta sair.
  def approve
    result = Payments::ProcessWebhook.new(approved_payload).call

    if result[:success]
      redirect_to checkout_success_path
    else
      redirect_to cart_path, alert: "O pagamento não foi confirmado: #{result[:message]}"
    end
  end

  # Recusado: nada de webhook. Só o caminho de falha que o CheckoutController
  # já usa — volta ao carrinho com o aviso. O pedido segue pending e a reserva
  # volta ao estoque pelo ExpireReservationsJob, como em qualquer desistência.
  def decline
    redirect_to cart_path, alert: "Pagamento não concluído. Seu carrinho continua aqui."
  end

  private

  def approved_payload
    {
      "order_nsu" => @order.order_nsu,
      # Único a cada clique: dois cliques são dois eventos, e o segundo tem que
      # passar pela idempotência do ProcessWebhook em vez de ser descartado
      # como repetição do primeiro.
      "transaction_nsu" => "fake-#{SecureRandom.uuid}",
      "invoice_slug" => "fake-#{@order.order_nsu}",
      "amount" => @order.total_cents,
      "paid_amount" => @order.total_cents,
      "installments" => 1,
      "capture_method" => "pix"
    }
  end

  def ensure_fake_mode
    head :not_found unless InfinitepayClient.fake_enabled?
  end

  def load_order
    @order = Order.find_by(order_nsu: params[:order_nsu])

    head :not_found if @order.nil?
  end
end

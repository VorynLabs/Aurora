module Webhooks
  # Endpoint chamado pela InfinitePay, não pelo navegador: herda de
  # ActionController::Base para ficar fora de sessão, layout e do
  # ApplicationController do site.
  class InfinitepayController < ActionController::Base
    # Requisição externa, sem sessão e sem token — CSRF não se aplica.
    skip_forgery_protection

    def create
      result = Payments::ProcessWebhook.new(webhook_params).call

      if result[:success]
        render json: { success: true, message: nil }, status: :ok
      else
        # 400 é o combinado com a InfinitePay para "não deu, reenvie depois".
        render json: { success: false, message: result[:message] }, status: :bad_request
      end
    end

    private

    def webhook_params
      params.permit(:invoice_slug, :amount, :paid_amount, :installments,
                    :capture_method, :transaction_nsu, :order_nsu, :receipt_url,
                    items: [:quantity, :price, :description]).to_h
    end
  end
end

module Payments
  # Passos 6 a 9 do SPEC 04: recebe o webhook da InfinitePay, garante que o
  # mesmo evento não baixe estoque duas vezes, confirma o pagamento com a
  # própria InfinitePay e só então dá baixa.
  #
  # Devolve um hash porque o controller responde JSON direto a partir dele.
  class ProcessWebhook
    include AmountMatching

    PROVIDER = "infinitepay".freeze

    def initialize(payload, client: InfinitepayClient.new)
      @payload = (payload || {}).to_h.with_indifferent_access
      @client = client
    end

    def call
      return failure("webhook sem transaction_nsu") if event_id.blank?
      return failure("webhook sem order_nsu") if order_nsu.blank?

      event = register_event
      # Outro processo criou o evento agora e ainda não commitou: ele está
      # cuidando desta transação. Responder 200 evita reenvio desnecessário.
      return success(:duplicate) if event.nil?
      return success(:duplicate) if event.processed?

      order = Order.find_by(order_nsu: order_nsu)
      return not_found(event) if order.nil?
      return already_paid(event) if order.paid?
      return refuse(event, "pedido cancelado") if order.canceled?

      confirm_and_settle(event, order)
    end

    private

    def event_id  = @payload[:transaction_nsu].presence
    def order_nsu = @payload[:order_nsu].presence

    # Idempotência (passo 6). O índice único (provider, event_id) é a trava de
    # verdade; a validação do model pega o caso sequencial e o índice pega o
    # concorrente, por isso os dois erros caem aqui.
    #
    # Só evento `processed` vira no-op lá em cima. Um evento `received`,
    # `ignored` ou `failed` é uma tentativa que não terminou — reprocessar é
    # seguro (o lock do pedido no SettlePaidOrder impede baixa dupla) e é o que
    # faz a retentativa da InfinitePay funcionar depois de uma falha nossa ou
    # de um pagamento que ainda não tinha compensado.
    def register_event
      WebhookEvent.create!(provider: PROVIDER, event_id: event_id, order_nsu: order_nsu,
                           payload: @payload, status: :received)
    rescue ActiveRecord::RecordNotUnique
      existing_event
    rescue ActiveRecord::RecordInvalid => e
      raise unless duplicate_event_id?(e.record)

      existing_event
    end

    def existing_event = WebhookEvent.find_by(provider: PROVIDER, event_id: event_id)

    def duplicate_event_id?(record) = record.errors.of_kind?(:event_id, :taken)

    def confirm_and_settle(event, order)
      # Passo 7: o webhook não é assinado, então a prova do pagamento é uma
      # consulta nossa à InfinitePay — nunca os números que chegaram no corpo.
      check = @client.payment_check(order, @payload)

      return refuse(event, "pagamento não confirmado no payment_check") unless check["paid"]
      return refuse(event, "valor pago menor que o total do pedido") unless amount_matches?(order, check)

      # Passo 8, com lock por variação dentro do serviço compartilhado.
      SettlePaidOrder.new(order, check, transaction_id: event_id).call

      event.update!(status: :processed, processed_at: Time.current)
      success(:processed)
    rescue InfinitepayClient::Error, Faraday::Error => e
      # Não deu para confirmar: nada de baixa. 400 faz a InfinitePay reenviar,
      # e o evento fica `failed` para a próxima tentativa reprocessar.
      event.update!(status: :failed)
      Rails.logger.error("[Payments::ProcessWebhook] payment_check falhou: #{e.message}")
      failure("não foi possível confirmar o pagamento agora")
    end

    def already_paid(event)
      event.update!(status: :processed, processed_at: Time.current)
      success(:already_paid)
    end

    def refuse(event, message)
      event.update!(status: :ignored)
      failure(message)
    end

    def not_found(event)
      event.update!(status: :failed)
      failure("pedido não encontrado")
    end

    def success(reason) = { success: true, reason: reason, message: nil }
    def failure(message) = { success: false, message: message }
  end
end

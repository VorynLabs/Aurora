# SPEC 04 — Pagamento, webhook e baixa de estoque

> Depende dos SPECs 00, 01 e 03. **Este é o núcleo do projeto.** Integra a InfinitePay como
> gateway, cria o pedido com reserva de estoque, gera o link de pagamento e — só ao confirmar
> o pagamento via webhook — dá baixa definitiva e atômica no estoque. Resolve o problema que
> motivou o sistema: estoque que não atualiza após a venda.
>
> Endpoints e payloads conferidos na documentação oficial da InfinitePay (Checkout Integrado,
> revisão de 22/07/2026). Preços sempre em **centavos**.

---

## Princípio central (leia antes de tudo)

> **O estoque só diminui quando o pagamento é confirmado por um canal servidor-a-servidor
> confiável — o webhook — e nunca antes.** O clique em "comprar" e o `redirect_url`
> ("página de obrigado") **não provam pagamento** e não podem disparar baixa. O cliente pode
> fechar o navegador, cair a conexão ou forjar a URL de retorno.

Três garantias inegociáveis:

1. **Reserva ≠ baixa.** No checkout, reservamos (seguramos) as unidades. A baixa real só no webhook pago.
2. **Idempotência.** O mesmo webhook pode chegar duas vezes. Processar duas vezes tiraria 2 do estoque numa venda só. Cada evento é registrado e reprocessar é no-op.
3. **Double-check.** A InfinitePay **não documenta assinatura HMAC** no webhook. Portanto, ao receber o webhook, **consultamos ativamente** o endpoint `payment_check` para confirmar que o pagamento é real e o valor bate, antes de dar baixa. O webhook é o gatilho; o `payment_check` é a prova.

---

## Fluxo completo

```
1. Cliente finaliza (carrinho ou "comprar agora")
        │
2. POST /checkout no nosso sistema
        │  - valida estoque disponível de cada variação
        │  - cria Order(status: pending, reserved_until: agora+30min)
        │  - cria OrderItems (variação, qtd, preço travado)
        │  - RESERVA: variant.reserved += qtd  (transação + lock)
        │
3. POST https://api.checkout.infinitepay.io/links
        │  - handle, order_nsu, redirect_url, webhook_url, items[]
        │  - recebe { "url": "https://checkout.infinitepay.com.br/..." }
        │  - salva payment_link_url no Order
        │
4. Redireciona cliente para a URL de pagamento
        │
5. Cliente paga (Pix ou cartão) no checkout InfinitePay
        │
6. InfinitePay → POST /webhooks/infinitepay (no nosso sistema)
        │  - registra WebhookEvent (idempotência via event_id único)
        │  - se já processado → responde 200 e para (no-op)
        │
7. DOUBLE-CHECK: POST /payment_check na InfinitePay
        │  - confirma paid: true e amount compatível
        │
8. BAIXA ATÔMICA (transação + lock pessimista por variação):
        │  - para cada OrderItem: variant.quantity -= qtd; variant.reserved -= qtd
        │  - Order.status = paid; paid_at = agora
        │  - WebhookEvent.status = processed
        │  (produto some do catálogo sozinho se a variação zerar — regra do SPEC 01)
        │
9. Responde 200 { success: true } em < 1s
```

Paralelamente (jobs):
- **Expiração de reservas:** pedidos `pending` com `reserved_until` vencido → devolve
  `reserved` ao estoque e marca `expired`.
- **Fallback de conciliação:** pedidos `pending` "antigos" → consulta `payment_check`; se pago, processa a baixa (mesma rotina do webhook).

---

## Endpoints da InfinitePay (referência)

### Criar link — `POST https://api.checkout.infinitepay.io/links`
Request:
```json
{
  "handle": "sua_infinite_tag",
  "redirect_url": "https://seusite.com/checkout/success",
  "webhook_url": "https://seusite.com/webhooks/infinitepay",
  "order_nsu": "ord_ab12cd34ef56",
  "items": [
    { "quantity": 2, "price": 4990, "description": "Camiseta básica — Preta / P" }
  ]
}
```
Response:
```json
{ "url": "https://checkout.infinitepay.com.br/sua_tag?lenc=codigo_unico" }
```
> `handle` = sua InfiniteTag sem o `$`. `price` em centavos. Pode incluir `customer` e
> `address` opcionais (não usados na v1 — checkout sem cadastro).

### Webhook recebido — `POST /webhooks/infinitepay` (no nosso sistema)
Payload enviado pela InfinitePay:
```json
{
  "invoice_slug": "abc123",
  "amount": 9980,
  "paid_amount": 10050,
  "installments": 1,
  "capture_method": "pix",
  "transaction_nsu": "UUID-da-transacao",
  "order_nsu": "ord_ab12cd34ef56",
  "receipt_url": "https://comprovante.com/123",
  "items": [ ... ]
}
```
Resposta esperada (rápida, < 1s):
```json
{ "success": true, "message": null }         // 200 → recebido
{ "success": false, "message": "motivo" }    // 400 → InfinitePay reenvia depois
```

### Double-check — `POST https://api.checkout.infinitepay.io/payment_check`
Request:
```json
{
  "handle": "sua_infinite_tag",
  "order_nsu": "ord_ab12cd34ef56",
  "transaction_nsu": "UUID-da-transacao",
  "slug": "abc123"
}
```
Response:
```json
{ "success": true, "paid": true, "amount": 9980, "paid_amount": 10050,
  "installments": 1, "capture_method": "pix" }
```

---

## Configuração

```ruby
# config/credentials.yml.enc  (rails credentials:edit)
infinitepay:
  handle: "sua_infinite_tag"
  base_url: "https://api.checkout.infinitepay.io"

# variáveis de ambiente / rotas
APP_BASE_URL = "https://seusite.com"   # para montar webhook_url e redirect_url
```

---

## Serviços (Service Objects)

### `Payments::CreateCheckout`
Responsabilidade única: dado um carrinho, criar o pedido, reservar estoque e obter o link.

```ruby
module Payments
  class CreateCheckout
    Result = Struct.new(:ok?, :order, :payment_url, :error)

    def initialize(cart) = @cart = cart

    def call
      order = nil
      ActiveRecord::Base.transaction do
        line_items = @cart.line_items
        raise Empty if line_items.empty?

        order = Order.create!(status: :pending, reserved_until: 30.minutes.from_now)

        line_items.each do |li|
          variant = Variant.lock.find(li[:variant].id)   # lock pessimista
          qty = li[:quantity]
          if variant.available_stock < qty
            raise OutOfStock, "#{variant.product.title} — #{variant.name}"
          end
          variant.update!(reserved: variant.reserved + qty)  # RESERVA (não baixa)
          order.order_items.create!(variant:, quantity: qty, price_cents: variant.price_cents)
        end
        order.update!(total_cents: order.order_items.sum { _1.quantity * _1.price_cents })
      end

      url = InfinitepayClient.new.create_link(order)   # chamada externa FORA da transação
      order.update!(payment_link_url: url)
      Result.new(true, order, url, nil)
    rescue OutOfStock => e
      Result.new(false, nil, nil, "Sem estoque: #{e.message}")
    rescue => e
      Result.new(false, nil, nil, e.message)
    end

    class Empty     < StandardError; end
    class OutOfStock < StandardError; end
  end
end
```
> **Chamada externa fora da transação de banco.** Não segure a transação (e os locks) esperando
> a rede da InfinitePay. Reserva-se em transação curta; depois chama-se a API. Se a API falhar,
> um job de expiração devolve a reserva.

### `Payments::ProcessWebhook`
Responsabilidade única: idempotência + double-check + baixa atômica.

```ruby
module Payments
  class ProcessWebhook
    def initialize(payload) = @payload = payload

    def call
      event_id = @payload["transaction_nsu"]
      order_nsu = @payload["order_nsu"]

      # 1) idempotência — trava por unique index (provider, event_id)
      event = WebhookEvent.create!(provider: "infinitepay", event_id:,
                                   order_nsu:, payload: @payload, status: :received)

      order = Order.find_by!(order_nsu:)
      return ok(:already_paid) if order.paid?      # já processado antes

      # 2) double-check ativo (o webhook não é assinado)
      check = InfinitepayClient.new.payment_check(order, @payload)
      unless check["paid"] && amount_matches?(order, check)
        event.update!(status: :ignored)
        return fail("pagamento não confirmado no payment_check")
      end

      # 3) baixa atômica
      ActiveRecord::Base.transaction do
        order.order_items.includes(:variant).each do |item|
          variant = Variant.lock.find(item.variant_id)
          variant.update!(
            quantity: variant.quantity - item.quantity,
            reserved: [variant.reserved - item.quantity, 0].max
          )
        end
        order.update!(status: :paid, paid_at: Time.current,
                      transaction_id: event_id)
        event.update!(status: :processed, processed_at: Time.current)
      end
      ok(:processed)
    rescue ActiveRecord::RecordNotUnique
      ok(:duplicate)      # webhook repetido chegou junto — idempotente
    rescue ActiveRecord::RecordNotFound
      fail("pedido não encontrado")
    end

    private
    def amount_matches?(order, check)
      # tolera diferença de juros de parcelamento: paga o total do pedido ou mais
      check["amount"].to_i >= order.total_cents ||
        check["paid_amount"].to_i >= order.total_cents
    end
    def ok(reason)   = { success: true,  reason: }
    def fail(msg)    = { success: false, message: msg }
  end
end
```

### `InfinitepayClient`
Wrapper HTTP (Faraday — você já conhece do contexto Rails). Métodos: `create_link(order)`,
`payment_check(order, payload)`. Base URL e handle vêm das credentials.

> **Resiliência:** as chamadas à InfinitePay (`create_link`, `payment_check`) são candidatas
> naturais ao seu próprio `resilient_call` quando ele estiver publicado — retry com backoff +
> circuit breaker nomeado `:infinitepay`. Na v1, um retry simples basta; deixe o ponto de
> extensão marcado.

---

## Controller do webhook

```ruby
class Webhooks::InfinitepayController < ActionController::Base
  skip_forgery_protection            # requisição externa, sem sessão/CSRF

  def create
    result = Payments::ProcessWebhook.new(webhook_params).call
    if result[:success]
      render json: { success: true, message: nil }, status: :ok
    else
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
```
> Responder em < 1s. Se a baixa for pesada, dá pra registrar o evento, responder 200 e
> processar a baixa num job — mas então a resposta 200 significa "recebi", e a baixa é
> garantida pelo job + idempotência. Na v1, o processamento síncrono acima é aceitável
> por ser curto (poucos itens). Meça antes de otimizar.

---

## Jobs

### `ExpireReservationsJob` (a cada ~5 min)
```ruby
class ExpireReservationsJob < ApplicationJob
  def perform
    Order.stale_pending.find_each do |order|
      ActiveRecord::Base.transaction do
        order.order_items.includes(:variant).each do |item|
          v = Variant.lock.find(item.variant_id)
          v.update!(reserved: [v.reserved - item.quantity, 0].max)   # devolve reserva
        end
        order.update!(status: :expired)
      end
    end
  end
end
```

### `ReconcilePendingPaymentsJob` (fallback, a cada ~10 min)
```ruby
class ReconcilePendingPaymentsJob < ApplicationJob
  def perform
    Order.pending.where(reserved_until: ..Time.current + 5.minutes).find_each do |order|
      next if order.transaction_id.blank? && order.payment_link_url.blank?
      check = InfinitepayClient.new.payment_check(order, {})   # consulta por order_nsu/slug
      next unless check["paid"]
      # reusa a rotina de baixa do ProcessWebhook (extrair para método compartilhado)
      Payments::SettlePaidOrder.new(order, check).call
    end
  end
end
```
> Fallback cobre o caso do webhook não chegar (servidor fora do ar no momento, etc.).
> Mesma idempotência: se o webhook chegar depois, o pedido já estará `paid` e será no-op.

---

## Segurança do endpoint de webhook

Como não há assinatura HMAC documentada:
- **Não confie no payload por si só.** A confirmação vem do `payment_check` (double-check).
- Valide que `order_nsu` corresponde a um pedido real e `pending`.
- Considere restringir por IP de origem da InfinitePay se eles publicarem a faixa.
- URL do webhook não precisa ser secreta, mas evite vazá-la; use HTTPS sempre.
- Nunca dê baixa baseado apenas nos números do webhook — sempre reconfirme valor via `payment_check`.

---

## Casos de borda (todos devem ter teste)

| Caso | Comportamento esperado |
|---|---|
| Webhook chega 2× (duplicado) | Segundo é no-op; estoque baixa uma vez só |
| Webhook chega, mas `payment_check` diz `paid: false` | Não baixa; evento `ignored`; responde 400 |
| Pagamento parcial / valor menor que o pedido | Não baixa; investigar; responde 400 |
| Parcelamento com juros (`paid_amount` > `amount`) | Baixa normal (valor cobre o pedido) |
| Cliente paga após a reserva expirar | `payment_check` confirma pago → baixa mesmo assim; se faltar estoque, registrar e alertar (não vender o que não há) |
| Dois checkouts disputam a última unidade | Lock pessimista: um reserva, o outro recebe "sem estoque" |
| Webhook chega antes do nosso `create_link` retornar | Pedido já existe (criado antes da chamada externa); processa normal |
| InfinitePay fora do ar no `create_link` | Checkout falha graciosamente; reserva expira e volta ao estoque |

---

## Checklist de testes — pagamento

### `create_checkout_spec.rb`
- [ ] cria Order pending com reserved_until futuro
- [ ] reserva (`reserved +=`) cada variação sem baixar `quantity`
- [ ] falha com "sem estoque" se `available_stock < qtd`
- [ ] trava a última unidade sob concorrência (lock) — dois checkouts, um falha
- [ ] chamada à InfinitePay ocorre fora da transação
- [ ] salva `payment_link_url` no pedido

### `process_webhook_spec.rb`
- [ ] webhook válido dá baixa (`quantity -=`, `reserved -=`) e marca `paid`
- [ ] webhook duplicado (mesmo `transaction_nsu`) é no-op idempotente
- [ ] `payment_check` retornando `paid: false` não baixa e responde 400
- [ ] valor menor que o pedido não baixa
- [ ] `paid_amount` maior (juros de parcela) baixa normalmente
- [ ] variação que zera some do catálogo (via regra do SPEC 01, sem código extra)
- [ ] responde 200 `{ success: true }` no caminho feliz
- [ ] pedido inexistente responde 400 `{ success: false }`
- [ ] `sleep`/HTTP externo são stubbados (sem rede real, sem sleep real nos specs)

### `expire_reservations_job_spec.rb`
- [ ] devolve `reserved` ao estoque de pedidos pendentes vencidos
- [ ] marca pedido como `expired`
- [ ] não toca em pedidos ainda dentro do prazo

### `reconcile_pending_payments_job_spec.rb`
- [ ] pedido pendente que consta pago no `payment_check` é baixado
- [ ] pedido não pago permanece pendente
- [ ] pedido já `paid` é ignorado (idempotência)
```

# Cliente HTTP do Checkout Integrado da InfinitePay.
class InfinitepayClient
  class Error < StandardError; end

  # Caminhos públicos deste app que a InfinitePay chama de volta.
  SUCCESS_PATH = "/checkout/success"
  WEBHOOK_PATH = "/webhooks/infinitepay"

  # Página de "pagamento simulado" do modo fake, no lugar do checkout deles.
  FAKE_CHECKOUT_PATH = "/dev/fake_checkout"

  TIMEOUT = 10
  OPEN_TIMEOUT = 5

  # O webhook precisa de resposta em menos de 1s e o payment_check acontece
  # dentro dele, então essa chamada tem prazo bem mais curto que o create_link:
  # é melhor devolver 400 e deixar a InfinitePay reenviar do que segurar a
  # conexão dela.
  CHECK_TIMEOUT = 3
  CHECK_OPEN_TIMEOUT = 2

  # Modo fake: desenvolver e testar o fluxo de pagamento sem conta na
  # InfinitePay e sem tocar na rede.
  #
  # Em produção é sempre false, mesmo com INFINITEPAY_FAKE=true no ambiente.
  # Um gateway simulado em produção daria pedido pago sem dinheiro entrando —
  # não é decisão que uma variável de ambiente deva poder tomar sozinha.
  #
  # Fora de produção a flag manda. Sem flag, liga em development (é onde
  # serve) e fica desligado em test, onde a suíte exercita o caminho real com
  # o HTTP stubbado.
  # Lista explícita em vez de ActiveModel::Type::Boolean: aquele trata tudo que
  # não é "false"/"0"/"" como verdadeiro, e um INFINITEPAY_FAKE=talvez ligaria
  # o gateway simulado. Para esta flag, o que não é um "sim" claro é um não.
  FAKE_FLAG_ON = %w[true 1 yes on].freeze

  def self.fake_enabled?(env: Rails.env, flag: ENV["INFINITEPAY_FAKE"])
    return false if env.production?
    return env.development? if flag.blank?

    FAKE_FLAG_ON.include?(flag.to_s.strip.downcase)
  end

  def initialize(handle: nil, base_url: nil, app_base_url: nil, fake: nil)
    settings = Rails.configuration.x

    @handle = handle || settings.infinitepay.handle
    @base_url = base_url || settings.infinitepay.base_url
    @app_base_url = app_base_url || settings.app.base_url
    # Resolvido aqui, e não num initializer: constante do app não é
    # autocarregável durante o boot.
    @fake = fake.nil? ? self.class.fake_enabled? : fake
  end

  def fake? = !!@fake

  # Cria o link de pagamento do pedido e devolve a URL para onde mandar o
  # cliente. Preços em centavos, como o resto do sistema.
  def create_link(order)
    raise ArgumentError, "pedido sem itens" if order.order_items.empty?

    # Antes da checagem de handle: em development não há credencial nenhuma, e
    # é esse o caso que o modo fake existe para destravar.
    return fake_link(order) if fake?

    raise ArgumentError, "handle da InfinitePay não configurado" if @handle.blank?

    response = connection.post("/links", link_payload(order))

    raise Error, "InfinitePay respondeu #{response.status}" unless response.success?

    url = response.body.is_a?(Hash) ? response.body["url"] : nil
    raise Error, "InfinitePay não devolveu a URL de pagamento" if url.blank?

    url
  end

  # Double-check do passo 7 do SPEC 04. O webhook da InfinitePay não é
  # assinado, então ele é só o gatilho: a prova de que o pagamento existe e o
  # valor bate vem daqui, de uma chamada nossa para a API deles.
  #
  # O payload do webhook é opcional — o job de conciliação consulta só pelo
  # order_nsu, sem ter recebido webhook nenhum.
  def payment_check(order, payload = {})
    raise ArgumentError, "pedido sem order_nsu" if order.order_nsu.blank?

    return fake_check(order) if fake?

    raise ArgumentError, "handle da InfinitePay não configurado" if @handle.blank?

    response = connection.post("/payment_check") do |request|
      request.body = check_payload(order, payload)
      request.options.timeout = CHECK_TIMEOUT
      request.options.open_timeout = CHECK_OPEN_TIMEOUT
    end

    raise Error, "InfinitePay respondeu #{response.status}" unless response.success?
    raise Error, "InfinitePay devolveu uma resposta ilegível" unless response.body.is_a?(Hash)

    response.body
  end

  private

  # URL previsível, no próprio app: abre a página de pagamento simulado em vez
  # do checkout da InfinitePay.
  def fake_link(order)
    public_url("#{FAKE_CHECKOUT_PATH}?order_nsu=#{CGI.escape(order.order_nsu)}")
  end

  # Mesmo formato do payment_check real (SPEC 04). O valor é o total do pedido
  # para o amount_matches? do webhook aprovar.
  def fake_check(order)
    {
      "success" => true,
      "paid" => true,
      "amount" => order.total_cents,
      "paid_amount" => order.total_cents,
      "installments" => 1,
      "capture_method" => "pix"
    }
  end

  def link_payload(order)
    {
      handle: @handle,
      order_nsu: order.order_nsu,
      redirect_url: public_url(SUCCESS_PATH),
      webhook_url: public_url(WEBHOOK_PATH),
      items: order.order_items.map { |item| item_payload(item) }
    }
  end

  def item_payload(item)
    variant = item.variant

    {
      quantity: item.quantity,
      price: item.price_cents,
      description: "#{variant.product.title} — #{variant.name}"
    }
  end

  # transaction_nsu e slug identificam a transação específica; sem webhook em
  # mãos, sobra o que o pedido já guardou. Chaves vazias saem do corpo para não
  # mandar null para a API.
  def check_payload(order, payload)
    data = (payload || {}).to_h.with_indifferent_access

    {
      handle: @handle,
      order_nsu: order.order_nsu,
      transaction_nsu: data[:transaction_nsu].presence || order.transaction_id,
      slug: data[:invoice_slug].presence
    }.compact_blank
  end

  def public_url(path) = "#{@app_base_url.to_s.chomp('/')}#{path}"

  def connection
    @connection ||= Faraday.new(url: @base_url) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.options.timeout = TIMEOUT
      faraday.options.open_timeout = OPEN_TIMEOUT
    end
  end
end

# Cliente HTTP do Checkout Integrado da InfinitePay.
class InfinitepayClient
  class Error < StandardError; end

  # Caminhos públicos deste app que a InfinitePay chama de volta. O webhook
  # ganha rota no próximo escopo; o caminho já é o do SPEC 00.
  SUCCESS_PATH = "/checkout/success"
  WEBHOOK_PATH = "/webhooks/infinitepay"

  def initialize(handle: nil, base_url: nil, app_base_url: nil)
    settings = Rails.configuration.x

    @handle = handle || settings.infinitepay.handle
    @base_url = base_url || settings.infinitepay.base_url
    @app_base_url = app_base_url || settings.app.base_url
  end

  # Cria o link de pagamento do pedido e devolve a URL para onde mandar o
  # cliente. Preços em centavos, como o resto do sistema.
  def create_link(order)
    raise ArgumentError, "handle da InfinitePay não configurado" if @handle.blank?
    raise ArgumentError, "pedido sem itens" if order.order_items.empty?

    response = connection.post("/links", link_payload(order))

    raise Error, "InfinitePay respondeu #{response.status}" unless response.success?

    url = response.body.is_a?(Hash) ? response.body["url"] : nil
    raise Error, "InfinitePay não devolveu a URL de pagamento" if url.blank?

    url
  end

  private

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

  def public_url(path) = "#{@app_base_url.to_s.chomp('/')}#{path}"

  def connection
    @connection ||= Faraday.new(url: @base_url) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
    end
  end
end

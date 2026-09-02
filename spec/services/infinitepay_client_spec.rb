require "rails_helper"

RSpec.describe InfinitepayClient do
  subject(:client) { described_class.new }

  let(:links_url) { "https://api.checkout.infinitepay.io/links" }
  let(:payment_url) { "https://checkout.infinitepay.com.br/aurora_test?lenc=abc123" }

  let(:order) { create(:order, order_nsu: "ord_ab12cd34ef56") }
  let(:variant) do
    create(:variant, name: "Preta / P", price_cents: 4_990,
           product: create(:product, title: "Camisola de cetim"))
  end

  before do
    create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990)
    order.reload
  end

  def stub_links(status: 200, body: { "url" => payment_url })
    stub_request(:post, links_url).to_return(
      status: status, body: body.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  describe "#create_link" do
    it "devolve a URL de pagamento" do
      stub_links

      expect(client.create_link(order)).to eq(payment_url)
    end

    it "envia handle, order_nsu e as URLs de retorno" do
      stub_links

      client.create_link(order)

      expect(WebMock).to have_requested(:post, links_url).with { |request|
        body = JSON.parse(request.body)

        body["handle"] == "aurora_test" &&
          body["order_nsu"] == "ord_ab12cd34ef56" &&
          body["redirect_url"] == "https://aurora.test/checkout/success" &&
          body["webhook_url"] == "https://aurora.test/webhooks/infinitepay"
      }
    end

    it "monta os itens em centavos, com produto e variação na descrição" do
      stub_links

      client.create_link(order)

      expect(WebMock).to have_requested(:post, links_url).with { |request|
        JSON.parse(request.body)["items"] == [
          { "quantity" => 2, "price" => 4_990, "description" => "Camisola de cetim — Preta / P" }
        ]
      }
    end

    it "usa o preço travado no pedido, não o preço atual da variação" do
      variant.update!(price_cents: 9_990)
      stub_links

      client.create_link(order)

      expect(WebMock).to have_requested(:post, links_url).with { |request|
        JSON.parse(request.body)["items"].first["price"] == 4_990
      }
    end

    it "manda JSON" do
      stub_links

      client.create_link(order)

      expect(WebMock).to have_requested(:post, links_url)
        .with(headers: { "Content-Type" => "application/json" })
    end

    describe "quando dá errado" do
      it "levanta erro em resposta 4xx" do
        stub_links(status: 422, body: { "error" => "handle inválido" })

        expect { client.create_link(order) }
          .to raise_error(described_class::Error, /422/)
      end

      it "levanta erro em resposta 5xx" do
        stub_links(status: 500, body: {})

        expect { client.create_link(order) }.to raise_error(described_class::Error)
      end

      it "levanta erro quando a resposta vem sem a URL" do
        stub_links(body: { "success" => true })

        expect { client.create_link(order) }
          .to raise_error(described_class::Error, /não devolveu a URL/)
      end

      it "recusa rodar sem handle configurado, antes de tocar na rede" do
        sem_handle = described_class.new(handle: "")

        expect { sem_handle.create_link(order) }
          .to raise_error(ArgumentError, /handle/)

        expect(WebMock).not_to have_requested(:post, links_url)
      end

      it "recusa pedido sem itens" do
        vazio = create(:order)

        expect { client.create_link(vazio) }.to raise_error(ArgumentError, /sem itens/)
      end
    end
  end

  describe "#payment_check" do
    let(:check_url) { "https://api.checkout.infinitepay.io/payment_check" }

    let(:webhook_payload) do
      { "transaction_nsu" => "UUID-da-transacao", "invoice_slug" => "abc123",
        "amount" => 9_980, "paid_amount" => 10_050 }
    end

    def stub_check(status: 200, body: { "success" => true, "paid" => true, "amount" => 9_980 })
      stub_request(:post, check_url).to_return(
        status: status, body: body.to_json, headers: { "Content-Type" => "application/json" }
      )
    end

    it "devolve a resposta da InfinitePay" do
      stub_check

      expect(client.payment_check(order, webhook_payload))
        .to include("paid" => true, "amount" => 9_980)
    end

    it "identifica a transação por handle, order_nsu, transaction_nsu e slug" do
      stub_check

      client.payment_check(order, webhook_payload)

      expect(WebMock).to have_requested(:post, check_url).with(
        body: { handle: "aurora_test", order_nsu: "ord_ab12cd34ef56",
                transaction_nsu: "UUID-da-transacao", slug: "abc123" }
      )
    end

    it "aceita chaves símbolo no payload" do
      stub_check

      client.payment_check(order, webhook_payload.symbolize_keys)

      expect(WebMock).to have_requested(:post, check_url).with { |request|
        JSON.parse(request.body)["transaction_nsu"] == "UUID-da-transacao"
      }
    end

    it "consulta só pelo pedido quando não há webhook em mãos (conciliação)" do
      order.update!(transaction_id: "trx-salva-no-pedido")
      stub_check

      client.payment_check(order)

      expect(WebMock).to have_requested(:post, check_url).with(
        body: { handle: "aurora_test", order_nsu: "ord_ab12cd34ef56",
                transaction_nsu: "trx-salva-no-pedido" }
      )
    end

    it "omite as chaves que não tem em vez de mandar null" do
      stub_check

      client.payment_check(order)

      expect(WebMock).to have_requested(:post, check_url).with(
        body: { handle: "aurora_test", order_nsu: "ord_ab12cd34ef56" }
      )
    end

    describe "quando dá errado" do
      it "levanta erro em resposta 4xx" do
        stub_check(status: 422, body: { "error" => "transação inválida" })

        expect { client.payment_check(order, webhook_payload) }
          .to raise_error(described_class::Error, /422/)
      end

      it "levanta erro em resposta 5xx" do
        stub_check(status: 500, body: {})

        expect { client.payment_check(order, webhook_payload) }
          .to raise_error(described_class::Error)
      end

      it "levanta erro quando a resposta não é JSON" do
        stub_request(:post, check_url).to_return(status: 200, body: "pong")

        expect { client.payment_check(order, webhook_payload) }
          .to raise_error(described_class::Error, /ilegível/)
      end

      it "recusa rodar sem handle configurado, antes de tocar na rede" do
        sem_handle = described_class.new(handle: "")

        expect { sem_handle.payment_check(order, webhook_payload) }
          .to raise_error(ArgumentError, /handle/)

        expect(WebMock).not_to have_requested(:post, check_url)
      end
    end
  end
end

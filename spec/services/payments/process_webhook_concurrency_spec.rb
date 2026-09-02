require "rails_helper"

# Sem transação de teste: o lock pessimista só se prova entre conexões de
# verdade, e a transação que o RSpec abre isolaria as threads uma da outra.
RSpec.describe Payments::ProcessWebhook, "sob concorrência" do
  self.use_transactional_tests = false

  let(:check_url) { "https://api.checkout.infinitepay.io/payment_check" }

  let!(:variant) { create(:variant, quantity: 5, reserved: 2, price_cents: 4_990) }
  let!(:order) { create(:order, status: :pending, total_cents: 9_980) }

  before do
    create(:order_item, order: order, variant: variant, quantity: 2, price_cents: 4_990)

    stub_request(:post, check_url).to_return(
      status: 200,
      body: { "success" => true, "paid" => true, "amount" => 9_980, "paid_amount" => 9_980 }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  after do
    WebhookEvent.delete_all
    OrderItem.delete_all
    Order.delete_all
    Variant.delete_all
    Product.delete_all
    Category.delete_all
    Admin.delete_all
  end

  def payload(transaction_nsu: "trx-1")
    { "invoice_slug" => "abc123", "amount" => 9_980, "paid_amount" => 9_980,
      "transaction_nsu" => transaction_nsu, "order_nsu" => order.order_nsu }
  end

  def in_thread(results, mutex, &block)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        outcome = block.call

        mutex.synchronize { results << outcome }
      end
    end
  end

  def run_parallel(*blocks)
    results = []
    mutex = Mutex.new

    blocks.map { |block| in_thread(results, mutex, &block) }.each(&:join)

    results
  end

  describe "o mesmo webhook chegando duas vezes ao mesmo tempo" do
    def process_twice
      run_parallel(
        -> { described_class.new(payload).call },
        -> { described_class.new(payload).call }
      )
    end

    it "baixa o estoque uma vez só" do
      process_twice

      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
    end

    it "grava um evento só, pela unicidade de (provider, event_id)" do
      process_twice

      expect(WebhookEvent.count).to eq(1)
    end

    it "responde sucesso nas duas entregas" do
      results = process_twice

      expect(results.map { _1[:success] }).to all(be(true))
    end

    it "deixa o pedido pago uma vez" do
      process_twice

      expect(order.reload).to be_paid
    end
  end

  describe "webhook e conciliação disputando o mesmo pedido" do
    it "baixa o estoque uma vez só" do
      check = { "paid" => true, "amount" => 9_980, "paid_amount" => 9_980 }

      run_parallel(
        -> { described_class.new(payload).call },
        -> { Payments::SettlePaidOrder.new(order, check).call }
      )

      expect(variant.reload).to have_attributes(quantity: 3, reserved: 0)
      expect(order.reload).to be_paid
    end
  end

  describe "duas transações diferentes para o mesmo pedido" do
    it "baixa o estoque uma vez só (a segunda encontra o pedido pago)" do
      run_parallel(
        -> { described_class.new(payload(transaction_nsu: "trx-1")).call },
        -> { described_class.new(payload(transaction_nsu: "trx-2")).call }
      )

      expect(variant.reload.quantity).to eq(3)
      expect(WebhookEvent.count).to eq(2)
      expect(order.reload).to be_paid
    end
  end
end

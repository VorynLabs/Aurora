require "rails_helper"

# Sem transação de teste: o lock pessimista só se prova entre conexões de
# verdade, e a transação que o RSpec abre isolaria as threads uma da outra.
RSpec.describe Payments::CreateCheckout, "sob concorrência" do
  self.use_transactional_tests = false

  let(:client) { instance_double(InfinitepayClient, create_link: "https://checkout.test/abc") }

  after do
    OrderItem.delete_all
    Order.delete_all
    Variant.delete_all
    Product.delete_all
    Category.delete_all
    Admin.delete_all
  end

  def checkout_in_thread(variant, results, mutex)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        cart = Cart.ephemeral(variant.id, 1)
        result = described_class.new(cart, client: client).call

        mutex.synchronize { results << result }
      end
    end
  end

  it "deixa só um dos dois checkouts reservar a última unidade" do
    variant = create(:variant, quantity: 1, reserved: 0)
    results = []
    mutex = Mutex.new

    2.times.map { checkout_in_thread(variant, results, mutex) }.each(&:join)

    expect(results.count(&:ok?)).to eq(1)
    expect(results.reject(&:ok?).map(&:error)).to all(match(/Sem estoque/))
  end

  it "não deixa a reserva passar do estoque físico" do
    variant = create(:variant, quantity: 1, reserved: 0)
    results = []
    mutex = Mutex.new

    2.times.map { checkout_in_thread(variant, results, mutex) }.each(&:join)

    variant.reload
    expect(variant.reserved).to eq(1)
    expect(variant.quantity).to eq(1)
    expect(variant.available_stock).to eq(0)
  end

  it "abre um pedido só" do
    variant = create(:variant, quantity: 1, reserved: 0)
    results = []
    mutex = Mutex.new

    2.times.map { checkout_in_thread(variant, results, mutex) }.each(&:join)

    expect(Order.count).to eq(1)
    expect(Order.first).to be_pending
  end
end

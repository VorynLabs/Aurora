require "rails_helper"

# Sem transação de teste: o lock pessimista só se prova entre conexões de
# verdade, e a transação que o RSpec abre isolaria as threads uma da outra.
RSpec.describe ExpireReservationsJob, "sob concorrência" do
  self.use_transactional_tests = false

  let!(:variant) { create(:variant, quantity: 5, reserved: 2, price_cents: 4_990) }
  let!(:order) do
    create(:order, status: :pending, reserved_until: 1.second.ago, total_cents: 9_980).tap do |o|
      create(:order_item, order: o, variant: variant, quantity: 2, price_cents: 4_990)
    end
  end

  let(:check) { { "paid" => true, "amount" => 9_980, "paid_amount" => 9_980 } }

  after do
    WebhookEvent.delete_all
    OrderItem.delete_all
    Order.delete_all
    Variant.delete_all
    Product.delete_all
    Category.delete_all
    Admin.delete_all
  end

  def run_parallel(*blocks)
    blocks.map { |block| Thread.new { ActiveRecord::Base.connection_pool.with_connection { block.call } } }
          .each(&:join)
  end

  # A corrida que estraga estoque: o pagamento entra no exato momento em que a
  # reserva vence. Um dos dois tem que ganhar por inteiro — nunca os dois.
  it "não solta a reserva duas vezes quando a baixa acontece junto" do
    run_parallel(
      -> { described_class.perform_now },
      -> { Payments::SettlePaidOrder.new(order, check).call }
    )

    variant.reload
    order.reload

    if order.paid?
      # A baixa ganhou: as unidades saíram do estoque e a reserva foi junto.
      expect(variant).to have_attributes(quantity: 3, reserved: 0)
    else
      # A expiração ganhou: nada saiu do estoque, só a reserva voltou.
      expect(order).to be_expired
      expect(variant).to have_attributes(quantity: 5, reserved: 0)
    end
  end

  it "não expira um pedido que acabou de ser pago" do
    run_parallel(
      -> { Payments::SettlePaidOrder.new(order, check).call },
      -> { described_class.perform_now }
    )

    expect(order.reload).to be_paid
  end

  it "duas rodadas simultâneas devolvem a reserva uma vez só" do
    run_parallel(-> { described_class.perform_now }, -> { described_class.perform_now })

    expect(variant.reload).to have_attributes(reserved: 0, quantity: 5)
    expect(order.reload).to be_expired
  end
end

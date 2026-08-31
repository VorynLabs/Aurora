require "rails_helper"

RSpec.describe OrderItem, type: :model do
  it "exige quantidade positiva" do
    item = build(:order_item, quantity: 0)

    expect(item).not_to be_valid
    expect(item.errors[:quantity]).to be_present
  end

  it "rejeita preço negativo" do
    item = build(:order_item, price_cents: -1)

    expect(item).not_to be_valid
    expect(item.errors[:price_cents]).to be_present
  end

  it "guarda o preço do momento da compra, independente do preço atual da variação" do
    variant = create(:variant, price_cents: 4_990)
    item = create(:order_item, variant: variant, price_cents: 4_990)

    variant.update!(price_cents: 9_990)

    expect(item.reload.price_cents).to eq(4_990)
  end

  it "não aceita a mesma variação duas vezes no mesmo pedido" do
    order = create(:order)
    variant = create(:variant)
    create(:order_item, order: order, variant: variant)

    expect { create(:order_item, order: order, variant: variant) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end

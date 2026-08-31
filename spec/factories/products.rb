FactoryBot.define do
  factory :product do
    admin
    category
    title { "Camiseta básica" }
    description { "Algodão penteado" }

    transient do
      variant_quantity { 10 }
      variant_reserved { 0 }
      variant_price_cents { 4_990 }
    end

    # Produto sem variação é inválido, então a fábrica já nasce com uma. Para
    # montar outro conjunto, passe `variants:` explicitamente.
    after(:build) do |product, evaluator|
      next if product.variants.any?

      product.variants << build(
        :variant,
        product: product,
        quantity: evaluator.variant_quantity,
        reserved: evaluator.variant_reserved,
        price_cents: evaluator.variant_price_cents
      )
    end
  end
end

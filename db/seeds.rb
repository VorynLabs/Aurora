# Dados de desenvolvimento. Rodar mais de uma vez não duplica nada.
#
# O admin nasce só com e-mail: as colunas de autenticação chegam com o Devise
# no próximo escopo.

admin = Admin.find_or_create_by!(email: "admin@aurora.local")

roupas = Category.find_or_create_by!(slug: "roupas") do |category|
  category.name = "Roupas"
  category.position = 1
end

unless admin.products.exists?(title: "Camiseta básica")
  admin.products.create!(
    title: "Camiseta básica",
    category: roupas,
    description: "Algodão penteado",
    variants_attributes: [
      { name: "Preta / P", price_cents: 4_990, quantity: 10 },
      # Sem estoque de propósito: a variação some do catálogo sozinha, e o
      # produto continua visível por causa da outra.
      { name: "Preta / M", price_cents: 4_990, quantity: 0 }
    ]
  )
end

puts "Seeds prontos: #{Admin.count} admin, #{Category.count} categoria(s), " \
     "#{Product.count} produto(s), #{Variant.count} variação(ões)."

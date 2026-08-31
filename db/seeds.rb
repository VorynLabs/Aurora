# Dados de desenvolvimento. Rodar mais de uma vez não duplica nada.

# Senha do admin de desenvolvimento. Rodar os seeds redefine a senha, o que
# também destrava o registro criado antes do Devise existir.
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "trocar-isto-123")

admin = Admin.find_or_initialize_by(email: "admin@aurora.local")
admin.password = admin_password
admin.save!

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

# SPEC 01 — Modelo de dados

> Depende do SPEC 00. Define schema, migrations, models, validações e a **regra canônica
> de visibilidade no catálogo**. Esta é a fundação; erre aqui e todo o resto sofre.

---

## Diagrama de entidades

```
Admin 1───* Product 1───* Variant 1───* OrderItem *───1 Order
                │                                          │
             Category                              WebhookEvent (idempotência)
```

- Um **Admin** possui muitos **Products** (multi-tenant preparado; hoje sempre o mesmo).
- Um **Product** pertence a uma **Category** e tem muitas **Variants**.
- Uma **Variant** carrega o estoque (`quantity`) e aparece em muitos **OrderItems**.
- Um **Order** tem muitos **OrderItems** e um status de pagamento.
- **WebhookEvent** registra webhooks já processados (idempotência — ver SPEC 04).

---

## Tabelas / migrations

### `admins`
Gerenciada pelo Devise (ver SPEC 02). Campos relevantes: `email`, `encrypted_password`.

### `categories`
```ruby
create_table :categories do |t|
  t.string  :name, null: false
  t.string  :slug, null: false
  t.integer :position, null: false, default: 0   # ordem de exibição do filtro
  t.timestamps
end
add_index :categories, :slug, unique: true
```

### `products`
```ruby
create_table :products do |t|
  t.references :admin,    null: false, foreign_key: true   # dono (multi-tenant futuro)
  t.references :category, null: false, foreign_key: true
  t.string  :title,       null: false
  t.text    :description
  t.boolean :hidden_by_admin, null: false, default: false  # ocultação manual
  t.timestamps
end
add_index :products, [:admin_id, :title]
```
> Imagem do produto: via **Active Storage** (`has_one_attached :image`). Sem coluna dedicada.

### `variants`
```ruby
create_table :variants do |t|
  t.references :product, null: false, foreign_key: true
  t.string  :name,     null: false          # ex.: "Preta / P" — rótulo humano da variação
  t.string  :sku
  t.integer :price_cents, null: false        # preço EM CENTAVOS (evita float em dinheiro)
  t.string  :currency,     null: false, default: "BRL"
  t.integer :quantity,     null: false, default: 0   # ESTOQUE vive aqui
  t.integer :reserved,     null: false, default: 0   # unidades reservadas (pedidos pendentes)
  t.timestamps
end
add_index :variants, :sku, unique: true, where: "sku IS NOT NULL"
add_index :variants, [:product_id, :name]
```
> **`quantity` = estoque físico total. `reserved` = quanto está segurado por pedidos pendentes.**
> Disponível para venda = `quantity - reserved`. A baixa (webhook pago) faz
> `quantity -= n` e `reserved -= n` juntos. Ver SPEC 04.

### `orders`
```ruby
create_table :orders do |t|
  t.string  :order_nsu, null: false              # id enviado à InfinitePay (conciliação)
  t.integer :status,    null: false, default: 0  # enum: pending/paid/expired/canceled
  t.integer :total_cents, null: false, default: 0
  t.string  :currency,    null: false, default: "BRL"
  t.string  :payment_link_url                    # link retornado pela InfinitePay
  t.string  :transaction_id                       # id da transação (preenchido no webhook)
  t.datetime :reserved_until                       # expira reserva se não pago até aqui
  t.datetime :paid_at
  t.timestamps
end
add_index :orders, :order_nsu, unique: true
add_index :orders, :status
```

### `order_items`
```ruby
create_table :order_items do |t|
  t.references :order,   null: false, foreign_key: true
  t.references :variant, null: false, foreign_key: true
  t.integer :quantity,    null: false           # unidades desta variação no pedido
  t.integer :price_cents, null: false           # preço NO MOMENTO da compra (histórico)
  t.timestamps
end
add_index :order_items, [:order_id, :variant_id], unique: true
```

### `webhook_events`
```ruby
create_table :webhook_events do |t|
  t.string  :provider,   null: false, default: "infinitepay"
  t.string  :event_id,   null: false             # id único do evento/transação do provedor
  t.string  :order_nsu
  t.integer :status,     null: false, default: 0 # received/processed/ignored/failed
  t.jsonb   :payload,    null: false, default: {}
  t.datetime :processed_at
  t.timestamps
end
add_index :webhook_events, [:provider, :event_id], unique: true   # trava idempotência
```

---

## Models

### `Admin`
```ruby
class Admin < ApplicationRecord
  devise :database_authenticatable, :rememberable, :validatable
  has_many :products, dependent: :destroy
end
```

### `Category`
```ruby
class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  before_validation :set_slug, if: -> { slug.blank? && name.present? }

  scope :ordered, -> { order(:position, :name) }

  private
  def set_slug = self.slug = name.parameterize
end
```

### `Product`
```ruby
class Product < ApplicationRecord
  belongs_to :admin
  belongs_to :category
  has_many   :variants, dependent: :destroy
  has_one_attached :image

  accepts_nested_attributes_for :variants, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:name].blank? && attrs[:price_cents].blank? }

  validates :title, presence: true
  validate  :must_have_at_least_one_variant

  # --- REGRA CANÔNICA DE VISIBILIDADE NO CATÁLOGO ---
  # Um produto aparece no catálogo se NÃO foi ocultado manualmente
  # E possui ao menos uma variação com estoque disponível (>= 1).
  scope :visible_in_catalog, -> {
    where(hidden_by_admin: false)
      .where(id: Variant.available.select(:product_id))
      .distinct
  }

  def visible_in_catalog?
    !hidden_by_admin && variants.any? { |v| v.available_stock >= 1 }
  end

  def min_price_cents = variants.available.minimum(:price_cents) || variants.minimum(:price_cents)

  private
  def must_have_at_least_one_variant
    return if variants.reject(&:marked_for_destruction?).any?
    errors.add(:base, "produto precisa de ao menos uma variação")
  end
end
```

### `Variant`
```ruby
class Variant < ApplicationRecord
  belongs_to :product

  validates :name, presence: true
  validates :price_cents, :quantity, :reserved,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # disponível = estoque físico menos o que está reservado por pedidos pendentes
  def available_stock = quantity - reserved

  scope :available, -> { where("quantity - reserved >= 1") }

  # helpers de dinheiro
  def price = price_cents / 100.0
  def price_brl = format("R$ %.2f", price).sub(".", ",")
end
```

### `Order`
```ruby
class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :variants, through: :order_items

  enum :status, { pending: 0, paid: 1, expired: 2, canceled: 3 }

  validates :order_nsu, presence: true, uniqueness: true

  before_validation :generate_order_nsu, on: :create

  scope :stale_pending, -> { pending.where("reserved_until < ?", Time.current) }

  private
  def generate_order_nsu = self.order_nsu ||= "ord_#{SecureRandom.hex(12)}"
end
```

### `OrderItem`
```ruby
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

### `WebhookEvent`
```ruby
class WebhookEvent < ApplicationRecord
  enum :status, { received: 0, processed: 1, ignored: 2, failed: 3 }
  validates :event_id, uniqueness: { scope: :provider }
end
```

---

## Regra de visibilidade — casos de teste (canônico)

| Situação | Aparece no catálogo? |
|---|---|
| `hidden_by_admin = true`, variações com estoque | ❌ não (ocultado manual) |
| `hidden_by_admin = false`, todas variações `quantity = 0` | ❌ não (sem estoque) |
| `hidden_by_admin = false`, 1 variação com `quantity >= 1` | ✅ sim |
| `hidden_by_admin = false`, `quantity = 5` mas `reserved = 5` | ❌ não (disponível = 0) |
| Variação individual `quantity = 0` num produto visível | variação some; produto fica se houver outra com estoque |

> **Importante:** a baixa que zera uma variação (no webhook) **não precisa** de código extra
> para "ocultar" — a visibilidade é derivada em query (`visible_in_catalog`). Some sozinho.
> Só a ocultação *manual* grava estado (`hidden_by_admin`).

---

## Seeds (desenvolvimento)

```ruby
admin = Admin.create!(email: "admin@aurora.local", password: "trocar-isto-123")
roupas = Category.create!(name: "Roupas", position: 1)
p = admin.products.create!(title: "Camiseta básica", category: roupas,
  description: "Algodão penteado")
p.variants.create!(name: "Preta / P", price_cents: 4990, quantity: 10)
p.variants.create!(name: "Preta / M", price_cents: 4990, quantity: 0)   # sem estoque
```

---

## Checklist de testes — modelo

### `product_spec.rb`
- [ ] inválido sem título
- [ ] inválido sem ao menos uma variação
- [ ] `visible_in_catalog` inclui produto com 1 variação disponível
- [ ] `visible_in_catalog` exclui produto `hidden_by_admin`
- [ ] `visible_in_catalog` exclui produto com todas variações em zero
- [ ] `visible_in_catalog` exclui produto com estoque todo reservado
- [ ] `min_price_cents` retorna o menor preço entre variações disponíveis

### `variant_spec.rb`
- [ ] `available_stock` = `quantity - reserved`
- [ ] scope `available` traz só variações com disponível >= 1
- [ ] rejeita `quantity` ou `reserved` negativos
- [ ] `price_brl` formata em reais com vírgula

### `order_spec.rb`
- [ ] gera `order_nsu` único no create
- [ ] enum de status funciona (pending → paid)
- [ ] scope `stale_pending` traz pendentes expirados

### `webhook_event_spec.rb`
- [ ] `event_id` único por provider (idempotência)

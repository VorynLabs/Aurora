# SPEC 03 — Catálogo público

> Depende dos SPECs 00 e 01. Área pública `/`, sem login. Listagem, detalhe do produto,
> busca, filtro por categoria (clique) e carrinho em sessão. Checkout direto (sem cadastro).

---

## Tela 1 — Listagem (`GET /`)

Mostra **apenas** produtos visíveis (regra `visible_in_catalog` do SPEC 01: não ocultos e
com ao menos uma variação disponível).

**Cada card exibe:** imagem, nome do produto, valor (menor preço entre variações disponíveis).

```ruby
class CatalogController < ApplicationController
  def index
    @categories = Category.ordered
    @products = Product.visible_in_catalog
                       .includes(:variants, :category, image_attachment: :blob)
    @products = @products.where(category_id: params[:category_id]) if params[:category_id]
    @products = search(@products, params[:q]) if params[:q].present?
  end

  private
  def search(scope, q)
    scope.where("title ILIKE :q OR description ILIKE :q", q: "%#{q}%")
  end
end
```

**Filtro por categoria (componente de clique):** uma faixa de "pills" com as categorias.
Clicar recarrega a lista filtrada. Com Turbo, o clique troca só a grade de produtos
(`turbo_frame` envolvendo `#catalog-grid`), sem reload da página inteira.

```erb
<nav class="flex gap-2 overflow-x-auto">
  <%= link_to "Todos", root_path, data: { turbo_frame: "catalog-grid" } %>
  <% @categories.each do |c| %>
    <%= link_to c.name, root_path(category_id: c.id), data: { turbo_frame: "catalog-grid" } %>
  <% end %>
</nav>

<turbo-frame id="catalog-grid">
  <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
    <%= render partial: "catalog/product_card", collection: @products %>
  </div>
</turbo-frame>
```

**Busca (componente de pesquisa):** input que submete `q`. Com Stimulus + Turbo, pode
buscar conforme digita (debounce) atualizando `#catalog-grid`.

```erb
<%= form_with url: root_path, method: :get, data: {
      turbo_frame: "catalog-grid",
      controller: "search", action: "input->search#submit"
    } do |f| %>
  <%= f.search_field :q, placeholder: "Buscar produtos...", value: params[:q] %>
<% end %>
```

---

## Tela 2 — Detalhe do produto (`GET /products/:id`)

Só acessível se o produto estiver visível (senão 404 — não expõe produto oculto/sem estoque).

**Exibe:** imagem, nome, valor, descrição. Mais:
- **Seletor de variação** (se houver mais de uma disponível): ex.: escolher "Preta / P".
  O preço e o estoque exibido acompanham a variação escolhida.
- **Seletor de quantidade** (stepper: − / n / +), limitado ao `available_stock` da variação.
- **Botão "Adicionar ao carrinho"**.
- **Botão "Comprar agora"** (vai direto ao checkout com só este item).

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.visible_in_catalog.find(params[:id])
    @variants = @product.variants.available
  end
end
```

> **Seletor de quantidade preso ao estoque:** o `max` do stepper é o `available_stock` da
> variação selecionada. Impede o cliente de pedir 5 quando há 3. A checagem real acontece
> de novo no checkout (não confie só no front).

---

## Tela 3 — Carrinho

Sem cadastro de cliente. O carrinho vive na **sessão** (ou cookie assinado). Guarda pares
`{ variant_id, quantity }`.

```ruby
class CartController < ApplicationController
  def show    = @cart = current_cart
  def add     # POST /cart/items
    current_cart.add(params[:variant_id], params[:quantity].to_i)
    respond_to { |f| f.turbo_stream }   # atualiza contador + mini-carrinho
  end
  def update  = (current_cart.set(params[:id], params[:quantity].to_i); render_cart)
  def remove  = (current_cart.remove(params[:id]); render_cart)

  private
  def current_cart = @current_cart ||= Cart.new(session)
end
```

```ruby
# app/models/cart.rb  (PORO sobre a sessão, não é ActiveRecord)
class Cart
  def initialize(session) = @items = (session[:cart] ||= {})
  def add(variant_id, qty)  = @items[variant_id.to_s] = (@items[variant_id.to_s].to_i + qty)
  def set(variant_id, qty)  = qty <= 0 ? remove(variant_id) : @items[variant_id.to_s] = qty
  def remove(variant_id)    = @items.delete(variant_id.to_s)
  def line_items
    variants = Variant.where(id: @items.keys)
    variants.map { |v| { variant: v, quantity: @items[v.id.to_s].to_i } }
  end
  def total_cents = line_items.sum { |li| li[:variant].price_cents * li[:quantity] }
  def empty? = @items.empty?
end
```

> **Hotwire no carrinho:** adicionar item responde `turbo_stream` que atualiza o badge do
> carrinho (contador) e o mini-carrinho, sem sair da página. Mudar quantidade/remover
> re-renderiza só a linha e o total.

---

## Do carrinho ao pagamento

Ambos os botões ("Comprar agora" e "Finalizar carrinho") levam ao mesmo ponto:
`POST /checkout`, detalhado no **SPEC 04**. Aqui o catálogo só entrega o carrinho; a criação
do pedido, a reserva de estoque e a geração do link InfinitePay são do SPEC 04.

**Entrega:** retirada no local ou envio via Uber/99 pago pelo cliente — **não há cálculo de
frete** no sistema. Na tela de checkout, um aviso/seleção simples ("Retirada" / "Envio por
app — combinar") apenas informa; não altera valor. (Frete calculado é roadmap v1.4.)

---

## Componentes de UI (resumo)

| Componente | Tipo | Nota |
|---|---|---|
| Card de produto | partial | imagem, nome, valor |
| Filtro de categoria | pills + turbo_frame | componente de clique, sem filtro "de verdade" complexo |
| Busca | form + Stimulus debounce | atualiza a grade |
| Seletor de variação | Stimulus | troca preço/estoque exibidos |
| Stepper de quantidade | Stimulus | limitado ao estoque disponível |
| Mini-carrinho | turbo_frame | contador + itens |

---

## Checklist de testes — catálogo

### Request/model specs
- [ ] `/` lista só produtos `visible_in_catalog`
- [ ] produto oculto não aparece na listagem nem no detalhe (404)
- [ ] produto sem estoque não aparece
- [ ] filtro por `category_id` restringe a lista
- [ ] busca por `q` casa título e descrição (case-insensitive)
- [ ] detalhe expõe só variações disponíveis
- [ ] `Cart#add` acumula quantidade da mesma variação
- [ ] `Cart#total_cents` soma preço × quantidade corretamente
- [ ] `Cart#set` com 0 remove o item

### System specs
- [ ] clicar numa categoria filtra sem reload (turbo_frame)
- [ ] digitar na busca atualiza a grade (debounce)
- [ ] stepper não deixa exceder o estoque da variação
- [ ] adicionar ao carrinho atualiza o contador via turbo_stream

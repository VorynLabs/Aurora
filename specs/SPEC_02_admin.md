# SPEC 02 — Painel de estoque (admin)

> Depende dos SPECs 00 e 01. Área privada `/admin`. Login, listagem de produtos, botão
> flutuante para adicionar, formulário com variações, edição, ocultar do catálogo e remover.

---

## Autenticação

- **Devise** no model `Admin`. Um admin hoje (criado via seed ou `rails console`).
  Sem tela pública de cadastro de admin.
- Todo o namespace `/admin` exige login (`before_action :authenticate_admin!`).
- Login em `/admin/login`, logout em `/admin/logout`.

```ruby
# config/routes.rb
devise_for :admins, path: "admin", controllers: { sessions: "admin/sessions" }

namespace :admin do
  root "products#index"
  resources :products do
    member { patch :toggle_visibility }
  end
end
```

```ruby
class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  layout "admin"
end
```

---

## Tela 1 — Lista de produtos (`GET /admin`)

Fonte da verdade do estoque. Mostra **todos** os produtos do admin (visíveis e ocultos,
com e sem estoque — é o painel interno, mostra tudo).

**Cada linha/card exibe:**
- Imagem (miniatura), título, categoria
- Preço (menor entre variações) e badge de estado:
  - `No catálogo` (verde) / `Oculto` (cinza) / `Sem estoque` (âmbar)
- Soma de estoque (Σ `quantity` das variações) e nº de variações
- Ícone de opções na lateral (menu: ocultar/mostrar, remover)

**Botão flutuante** no canto inferior direito (`+`) → abre formulário de novo produto.

```erb
<%# app/views/admin/products/index.html.erb %>
<div id="products" class="grid gap-3">
  <%= render @products %>   <%# _product.html.erb por item %>
</div>

<%# botão flutuante (Stimulus abre o modal/turbo_frame) %>
<button data-action="click->modal#open"
        class="fixed bottom-6 right-6 h-14 w-14 rounded-full bg-black text-white text-2xl shadow-lg">
  +
</button>
```

> **Hotwire aqui:** a lista é um alvo de `turbo_stream`. Ao criar/editar/remover/ocultar um
> produto, o controller responde com `turbo_stream` que insere/substitui/remove só aquele
> card em `#products`, sem recarregar a página.

---

## Tela 2 — Novo / Editar produto

Mesmo formulário para criar e editar (`_form.html.erb`). Campos pedidos:
**título, valor, descrição, quantidade, categoria, imagem** — mais as **variações**
(porque o estoque e o valor vivem na variação).

**Estrutura do formulário:**
- Título (texto)
- Descrição (textarea)
- Categoria (select das `Category.ordered`)
- Imagem (`file_field`, Active Storage)
- **Variações** (fields_for aninhado, `accepts_nested_attributes_for`):
  - cada linha: nome da variação (ex.: "Preta / P"), preço (em reais → converter p/ centavos),
    quantidade, SKU (opcional)
  - botão "adicionar variação" (Stimulus clona a linha; sem reload)
  - botão "remover variação" (marca `_destroy`)

```erb
<%# app/views/admin/products/_form.html.erb %>
<%= form_with model: [:admin, @product] do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area  :description %>
  <%= f.collection_select :category_id, Category.ordered, :id, :name %>
  <%= f.file_field :image %>

  <div data-controller="nested-variants">
    <template data-nested-variants-target="template">
      <%= f.fields_for :variants, Variant.new, child_index: "NEW_RECORD" do |vf| %>
        <%= render "variant_fields", vf: vf %>
      <% end %>
    </template>

    <div data-nested-variants-target="list">
      <%= f.fields_for :variants do |vf| %>
        <%= render "variant_fields", vf: vf %>
      <% end %>
    </div>

    <button type="button" data-action="nested-variants#add">+ variação</button>
  </div>

  <%= f.submit %>
<% end %>
```

> **Preço em centavos:** o input mostra reais (ex.: `49,90`); um helper/normalização no
> controller ou model converte para `price_cents` (4990). Nunca guarde dinheiro em float.
> Sugestão: campo virtual `price_reais` na Variant que faz `self.price_cents = (v.to_f*100).round`.

**Controllers:**
```ruby
class Admin::ProductsController < Admin::BaseController
  def index  = @products = current_admin.products.includes(:variants, :category).order(:title)
  def new    = @product = current_admin.products.new(variants: [Variant.new])
  def edit   = @product = current_admin.products.find(params[:id])

  def create
    @product = current_admin.products.new(product_params)
    if @product.save
      respond_to do |f|
        f.turbo_stream   # prepend do card em #products + fecha modal
        f.html { redirect_to admin_root_path, notice: "Produto criado" }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @product = current_admin.products.find(params[:id])
    if @product.update(product_params)
      respond_to do |f|
        f.turbo_stream   # replace do card
        f.html { redirect_to admin_root_path, notice: "Produto atualizado" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_visibility
    @product = current_admin.products.find(params[:id])
    @product.update!(hidden_by_admin: !@product.hidden_by_admin)
    respond_to { |f| f.turbo_stream }  # atualiza badge do card
  end

  def destroy
    current_admin.products.find(params[:id]).destroy!
    respond_to { |f| f.turbo_stream }  # remove card
  end

  private
  def product_params
    params.require(:product).permit(
      :title, :description, :category_id, :image,
      variants_attributes: [:id, :name, :sku, :price_reais, :quantity, :_destroy]
    )
  end
end
```

---

## Tela 3 — Ações do produto (menu lateral)

Ícone de opções em cada card abre menu (Stimulus dropdown):

| Ação | Efeito | Rota |
|---|---|---|
| **Editar** | abre form de edição | `edit_admin_product_path` |
| **Ocultar / Mostrar no catálogo** | alterna `hidden_by_admin` | `toggle_visibility` (PATCH) |
| **Remover** | apaga produto + variações (confirmação) | `DELETE` |

> "Ocultar" ≠ "Remover". Ocultar só tira do catálogo (reversível). Remover apaga da base
> (`dependent: :destroy` nas variações). Remover deve pedir confirmação
> (`data-turbo-confirm: "Remover da base?"`).

> **Estoque zerado ≠ ação manual.** Quando uma venda zera a variação, o produto some do
> catálogo **automaticamente** (regra derivada do SPEC 01) — o admin não precisa fazer nada,
> e volta sozinho ao repor estoque (`quantity >= 1`). O menu manual é só para ocultar
> deliberadamente algo que *tem* estoque.

---

## Stimulus controllers necessários

| Controller | Função |
|---|---|
| `modal` | abre/fecha o formulário de novo produto (botão flutuante) |
| `nested-variants` | adiciona/remove linhas de variação no form sem reload |
| `dropdown` | menu de opções lateral do card |
| `money-input` | máscara de reais no campo de preço (opcional) |

---

## Checklist de testes — admin

### Request specs
- [ ] `/admin` redireciona para login se não autenticado
- [ ] após login, lista mostra produtos do admin
- [ ] `POST /admin/products` cria produto com variações aninhadas
- [ ] `POST` com dados inválidos re-renderiza form (422)
- [ ] `PATCH /admin/products/:id` atualiza produto e variações
- [ ] `PATCH toggle_visibility` alterna `hidden_by_admin`
- [ ] `DELETE` remove produto e suas variações
- [ ] admin não acessa produto de outro admin (escopo `current_admin.products`)

### System specs (Hotwire)
- [ ] botão flutuante abre formulário
- [ ] adicionar variação cria nova linha sem reload
- [ ] criar produto insere card na lista via turbo_stream
- [ ] ocultar atualiza o badge sem recarregar
- [ ] remover pede confirmação e tira o card

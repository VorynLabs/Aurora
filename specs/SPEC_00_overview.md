# SPEC 00 — Aurora: visão geral do sistema de estoque e catálogo

> Documento raiz. Leia antes dos demais. Define stack, decisões arquiteturais,
> glossário e ordem de implementação. Os SPECs 01–05 detalham cada camada.
>
> **Nome do produto:** Aurora. O app Rails se chama `aurora` (banco `aurora_development`,
> módulo raiz `Aurora`). "Aurora" também é o nome do **tema visual** (paleta vinho + nude, no
> SPEC 05) — mesma marca, dois usos: o produto é a loja Aurora; o tema Aurora é a sua
> identidade visual. Onde houver risco de confusão, dizer "tema Aurora" para a paleta.

---

## O que é

Sistema próprio de **catálogo público** + **painel de estoque privado** para substituir a
gestão de estoque do painel da InfinitePay (mantendo a InfinitePay apenas como gateway de
pagamento, por causa das taxas). O problema central que este sistema resolve: **dar baixa
automática e confiável no estoque quando — e somente quando — um pagamento é confirmado.**

Dois lados no mesmo monolito Rails:

- **Catálogo** (`/`) — público, sem login. Cliente navega, busca, filtra por categoria,
  monta carrinho e paga via checkout InfinitePay.
- **Estoque** (`/admin`) — privado, com login. Admin cadastra/edita produtos e variações,
  oculta do catálogo, remove da base, e vê o estado do estoque.

---

## Stack

| Camada | Escolha | Motivo |
|---|---|---|
| Backend | **Rails 7.x** (monolito) | Uma linguagem, uma base, sem API separada |
| Front | **Hotwire (Turbo + Stimulus)** | Telas dinâmicas com ERB, sem SPA, sem build de JS pesado |
| CSS | **Tailwind** (`tailwindcss-rails`) | Utilitário, rápido, sem CSS artesanal |
| Design | **Aurora** (vinho + nude) | Identidade sofisticada/discreta do nicho. Ver SPEC 05 |
| Banco | **PostgreSQL** | Locks pessimistas confiáveis para a baixa de estoque atômica |
| Jobs | **Solid Queue** (Rails 7.1+) ou Sidekiq | Fallback de conciliação e liberação de reservas expiradas |
| Auth admin | **Devise** (ou `has_secure_password`) | Login do painel; nasce com 1 admin |
| Gateway | **InfinitePay Checkout Integrado** | `POST /links` + webhook. Ver SPEC 04 |

> **Nota sobre Hotwire:** é a primeira vez usando. A ideia-chave: o servidor manda **HTML**
> (não JSON) e o Turbo troca pedaços da página sem recarregar. `turbo_frame` isola uma região
> (ex.: um card de produto que vira formulário de edição no lugar). `turbo_stream` manda
> instruções de "insira/atualize/remova este elemento" (ex.: adicionar produto à lista sem
> reload). Stimulus é JS mínimo preso a atributos `data-controller` no HTML (ex.: o modal do
> botão flutuante). Não há estado duplicado entre back e front — o back é a fonte da verdade.

---

## Decisões arquiteturais (e o porquê)

1. **Estoque vive na variação, não no produto.** Como há variações (tamanho/cor), a
   quantidade é por `variant`. "Camiseta preta P" e "Camiseta preta M" são estoques
   separados. O produto agrupa; a variação tem `quantity` e pode ter preço próprio.

2. **Baixa de estoque só no webhook de pagamento confirmado.** Nunca no clique de "comprar",
   nunca no `redirect_url`. Este é o núcleo que corrige o problema da InfinitePay. Ver SPEC 04.

3. **Reserva ≠ baixa.** No início do checkout, o item é *reservado* (evita vender o mesmo
   último item duas vezes). A *baixa definitiva* só ocorre no webhook. Reservas não pagas
   expiram e voltam ao estoque via job.

4. **Idempotência no webhook.** Webhooks podem chegar duplicados. Cada pedido processado é
   registrado; reprocessar o mesmo é no-op. Sem isso, uma venda tira 2 do estoque.

5. **Multi-admin preparado, não implementado.** Hoje 1 admin. Mas produtos já nascem com
   `admin_id` (dono), para o futuro "cada admin com seus produtos e catálogos" não exigir
   migration dolorosa. A UI e as regras de hoje ignoram isso (sempre o admin único).

6. **Visibilidade no catálogo é derivada + manual.**
   - Manual: admin pode ocultar (`hidden_by_admin = true`).
   - Derivada: variação com `quantity == 0` não aparece; produto sem nenhuma variação
     disponível não aparece.
   - Um produto aparece no catálogo se: `hidden_by_admin == false` **E** tem ao menos uma
     variação com `quantity >= 1`. Ver a regra canônica no SPEC 01.

---

## Glossário

| Termo | Significado |
|---|---|
| Produto (`Product`) | Item do catálogo. Agrupa variações. Tem título, descrição, categoria, imagem. |
| Variação (`Variant`) | Combinação vendável (ex.: cor+tamanho). Tem `quantity`, preço, SKU. Estoque vive aqui. |
| Pedido (`Order`) | Um checkout. Tem status (`pending`, `paid`, `expired`, `canceled`) e `order_nsu`. |
| Item de pedido (`OrderItem`) | Linha do pedido: qual variação, quantas unidades, preço no momento. |
| Reserva | Estado transitório: unidades "seguradas" para um pedido pendente. |
| Baixa | Decremento definitivo de `quantity`, disparado pelo webhook pago. |
| `order_nsu` | Identificador único do pedido enviado à InfinitePay para conciliação. |
| Webhook | Chamada servidor-a-servidor da InfinitePay confirmando o pagamento. |

---

## Estrutura de rotas (visão macro)

```
# Público (catálogo)
GET    /                          # listagem do catálogo
GET    /products/:id              # detalhe do produto
GET    /search?q=...              # busca
GET    /categories/:id            # filtro por categoria (clique)
POST   /cart/items                # adiciona ao carrinho
PATCH  /cart/items/:id            # muda quantidade
DELETE /cart/items/:id            # remove do carrinho
GET    /cart                      # ver carrinho
POST   /checkout                  # cria pedido + link InfinitePay
GET    /checkout/success          # redirect_url (só UX, NÃO confia p/ estoque)

# Webhook (sem auth de sessão; validação própria — ver SPEC 04)
POST   /webhooks/infinitepay      # confirmação de pagamento

# Admin (autenticado)
GET    /admin/login
POST   /admin/login
DELETE /admin/logout
GET    /admin                     # lista de produtos cadastrados
GET    /admin/products/new
POST   /admin/products
GET    /admin/products/:id/edit
PATCH  /admin/products/:id
PATCH  /admin/products/:id/toggle_visibility
DELETE /admin/products/:id
# variações aninhadas no formulário de produto (accepts_nested_attributes)
```

---

## Ordem de implementação (branch-per-scope)

Seguindo seu fluxo habitual (branch por escopo, commits pequenos e coesos,
conventional commits, PRs pequenos):

| # | Branch | Entrega | SPEC |
|---|---|---|---|
| 1 | `feat/setup` | App Rails, Tailwind, Hotwire, Postgres, CI | 00 |
| 2 | `feat/data-model` | Migrations, models, validações, regra de visibilidade | 01 |
| 3 | `feat/admin-auth` | Devise, login, `/admin` protegido | 02 |
| 3.5 | `feat/design-system` | **Design Aurora: paleta, fontes, componentes, layouts base, styleguide** | 05 |
| 4 | `feat/admin-crud` | Lista, botão flutuante, form produto+variações, editar | 02 |
| 5 | `feat/admin-product-actions` | Ocultar do catálogo, remover da base | 02 |
| 6 | `feat/catalog-listing` | Catálogo público, imagem/nome/valor, filtro categoria | 03 |
| 7 | `feat/catalog-detail-search` | Detalhe, busca, seletor de quantidade | 03 |
| 8 | `feat/cart` | Carrinho (sessão), adicionar/comprar | 03 |
| 9 | `feat/payment-links` | Checkout: cria pedido + reserva + link InfinitePay | 04 |
| 10 | `feat/payment-webhook` | Webhook, double-check, baixa atômica, idempotência | 04 |
| 11 | `feat/payment-fallback` | Job de conciliação + expiração de reservas | 04 |

> O design (3.5) vem logo após o login e antes de qualquer tela de negócio, para que o CRUD
> (4) e o catálogo (6–8) já nasçam sobre os mesmos componentes visuais. Ver SPEC 05.

Cada item é um PR. Um só toca uma camada. Testes acompanham cada PR (ver checklist por SPEC).

---

## Fora de escopo da v1 (roadmap)

| Depois | Feature |
|---|---|
| v1.1 | Cadastro de cliente + histórico de pedidos |
| v1.2 | Multi-admin de fato (cada admin seu catálogo) |
| v1.3 | Relatórios de vendas / estoque baixo |
| v1.4 | Cálculo de frete (hoje: retirada ou Uber/99 pago pelo cliente) |
| v1.5 | Notificação ao admin quando estoque de uma variação zera |

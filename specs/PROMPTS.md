# PROMPTS — sequência para o Claude Code

> Um prompt por branch/escopo, na ordem do SPEC 00. Cole um de cada vez. Cada um assume que
> os SPECs (`SPEC_00_overview.md` … `SPEC_05_design.md`) estão na raiz do projeto e podem ser
> lidos. Commits pequenos e coesos, conventional commits, um PR por escopo.
>
> **Ordem do front:** o sistema de design (escopo 3.5, `feat/design-system`) vem depois do
> login do admin e ANTES do CRUD, para que todas as telas consumam os mesmos componentes.
>
> **Regras transversais (valem para todos os prompts):**
> - Preços sempre em centavos (inteiro). Nada de float para dinheiro.
> - Nos testes: sem `sleep` real (stub); prefira `and_raise`/`and_return`; lambdas nomeados.
> - Guard clauses de `ArgumentError` antes de lógica pesada.
> - Explicações concisas; foco em legibilidade para dev mid-level.
> - Não implemente nada além do escopo do prompt atual.

---

## 1 — `feat/setup`

```
Leia SPEC_00_overview.md. Crie um app Rails 7 (monolito, PostgreSQL) chamado `aurora`
configurado com:
- Tailwind via tailwindcss-rails
- Hotwire (Turbo + Stimulus) — já vem no Rails 7, confirme e configure
- Solid Queue (ou stub de ActiveJob) para os jobs que virão
- RSpec como framework de teste (remova o Minitest padrão)
- Estrutura de pastas e um README curto explicando como subir (setup, db:create, seeds)

Configure só o esqueleto. Sem models de domínio ainda. Faça commits pequenos e coesos
com conventional commits. Não crie nenhuma tela de negócio neste passo.
```

## 2 — `feat/data-model`

```
Leia SPEC_01_data_model.md. Implemente exatamente o modelo de dados descrito:
- migrations para categories, products, variants, orders, order_items, webhook_events
  (admins virá no próximo escopo, com Devise — por ora referencie admin_id como bigint
  com foreign_key a ser adicionada quando a tabela existir, OU crie uma tabela admins
  mínima só com email se for mais limpo; explique a escolha)
- models Product, Variant, Category, Order, OrderItem, WebhookEvent com as validações,
  enums, scopes e helpers do SPEC
- a REGRA CANÔNICA DE VISIBILIDADE (`Product.visible_in_catalog` e `visible_in_catalog?`)
  exatamente como especificada
- Active Storage para a imagem do produto (has_one_attached :image)
- seeds de desenvolvimento do SPEC

Escreva os specs de model listados no checklist do SPEC_01 (product, variant, order,
webhook_event), incluindo TODOS os casos da tabela "regra de visibilidade". Use FactoryBot.
```

## 3 — `feat/admin-auth`

```
Leia SPEC_02_admin.md (seção Autenticação). Adicione Devise ao model Admin:
- devise :database_authenticatable, :rememberable, :validatable
- namespace /admin protegido por authenticate_admin!
- login em /admin/login, logout em /admin/logout, sem tela pública de cadastro de admin
- ajuste a foreign key products.admin_id se ficou pendente do escopo anterior
- layout "admin" mínimo com Tailwind
- um admin de seed

Request specs: /admin redireciona para login quando deslogado; entra após login.
```

## 3.5 — `feat/design-system`

```
Leia SPEC_05_design.md. Monte o sistema de design "Aurora" (vinho + nude) ANTES de
qualquer tela de negócio:
- tema Tailwind com a paleta Aurora como tokens nomeados (wine, nude, clay, cream, etc.)
- fontes: uma serifada elegante para display/títulos e uma sans humanista para UI,
  carregadas com font-display: swap
- layout base do catálogo (header wine com marca + busca + carrinho; footer com selo de
  pagamento seguro e aviso 18+ textual, SEM modal de idade)
- layout base do admin (header wine-ink sóbrio, logout)
- componentes reutilizáveis (partials ou ViewComponents): button (primário/secundário/texto),
  input/select/textarea, card, badge, modal, dropdown, stepper de quantidade, flash/toast,
  image_placeholder, e image_field (preview da imagem atual sempre visível + botão trocar;
  no mobile nunca mostrar só o botão). Cards em creme/branco com borda (não nude-deep), para
  contraste no mobile.
- componente secure_payment_seal (cadeado + "pagamento seguro · Pix e cartão via InfinitePay")
- componente discreet_shipping_note com renderização condicional preparada (só aparece no
  fluxo de envio; ainda não ligado ao checkout)
- uma página interna de styleguide exibindo todos os componentes e cores juntos, para revisão

Tudo responsivo a partir de ~380px (mobile-first). Sentence case, tom acolhedor e adulto
conforme o SPEC. NÃO crie telas de produto/catálogo aqui — só o sistema visual e a styleguide.
```

## 4 — `feat/admin-crud`

```
Leia SPEC_02_admin.md (Telas 1 e 2) e use os componentes do SPEC_05_design.md
(button, input, card, badge, modal, dropdown) — não crie estilos novos, consuma os existentes.
Implemente:
- Admin::ProductsController (index, new, create, edit, update) escopado em
  current_admin.products
- lista de produtos (index) com card por produto: imagem, título, categoria, badge de
  estado (No catálogo/Oculto/Sem estoque), soma de estoque, nº de variações
- botão flutuante (+) no canto inferior direito que abre o formulário de novo produto
- formulário compartilhado (new/edit) com título, descrição, categoria (select), imagem,
  e variações aninhadas (accepts_nested_attributes_for) — cada variação com nome, preço
  em reais (converter para price_cents), quantidade, SKU opcional
- Stimulus controllers: modal (abre form), nested-variants (add/remove linha sem reload)
- respostas turbo_stream: criar faz prepend do card; atualizar faz replace

Converta preço reais→centavos com um campo virtual price_reais na Variant (SPEC 02).
Request specs + system specs (Hotwire) do checklist do SPEC_02.
```

## 5 — `feat/admin-product-actions`

```
Leia SPEC_02_admin.md (Tela 3). Implemente:
- menu de opções lateral em cada card (Stimulus dropdown): Editar, Ocultar/Mostrar, Remover
- toggle_visibility (PATCH, member route) alternando hidden_by_admin, atualizando o badge
  via turbo_stream sem reload
- destroy removendo produto + variações (dependent: :destroy), com confirmação
  (data-turbo-confirm) e turbo_stream removendo o card

NÃO adicione lógica para ocultar por estoque zerado — isso é derivado da regra de
visibilidade (SPEC 01) e não precisa de ação manual. Só a ocultação manual grava estado.
Cubra com request + system specs.
```

## 6 — `feat/catalog-listing`

```
Leia SPEC_03_catalog.md (Tela 1) e use os componentes/layout do SPEC_05_design.md
(card de produto sobre o layout base do catálogo, badge de estoque, componente de busca).
Implemente o catálogo público em /:
- CatalogController#index listando SÓ Product.visible_in_catalog
- card público: imagem, nome, menor preço entre variações disponíveis
- filtro por categoria como pills clicáveis dentro de um turbo_frame (#catalog-grid),
  troca a grade sem recarregar a página
- busca (q) por título e descrição, case-insensitive (ILIKE), atualizando #catalog-grid;
  Stimulus com debounce no input

Request/model + system specs do checklist do SPEC_03 referentes a listagem, filtro e busca.
```

## 7 — `feat/catalog-detail`

```
Leia SPEC_03_catalog.md (Tela 2). Implemente:
- ProductsController#show acessível só para produtos visíveis (404 caso contrário)
- detalhe: imagem, nome, valor, descrição
- seletor de variação (quando houver mais de uma disponível) que atualiza preço/estoque
  exibidos (Stimulus)
- stepper de quantidade limitado ao available_stock da variação selecionada
- botões "Adicionar ao carrinho" e "Comprar agora" (as rotas de carrinho/checkout serão
  ligadas nos próximos escopos; deixe os caminhos preparados)
- inclua o componente secure_payment_seal (SPEC_05) perto dos botões de compra

System specs: detalhe some para produto oculto/sem estoque; stepper respeita o estoque.
```

## 8 — `feat/cart`

```
Leia SPEC_03_catalog.md (Tela 3). Implemente o carrinho em sessão:
- PORO Cart (app/models/cart.rb) sobre a session, com add/set/remove/line_items/
  total_cents/empty?
- CartController: show, add, update, remove
- mini-carrinho e contador atualizados via turbo_stream ao adicionar/alterar/remover
- "Comprar agora" cria um carrinho efêmero com só o item e segue para o checkout

Model specs do Cart (acúmulo, total, remoção por qtd 0) + system spec do fluxo de adicionar.
```

## 9 — `feat/payment-links`

```
Leia SPEC_04_payment.md (fluxo passos 1–4 e Payments::CreateCheckout). Implemente:
- InfinitepayClient (Faraday) com create_link(order) chamando
  POST https://api.checkout.infinitepay.io/links usando handle das credentials,
  montando items[] a partir dos order_items (price em centavos, description
  "Produto — Variação"), enviando order_nsu, redirect_url e webhook_url
- Payments::CreateCheckout: transação curta com lock pessimista que valida estoque,
  cria Order(pending, reserved_until: 30.min), cria OrderItems com preço travado, e
  RESERVA (variant.reserved += qtd) SEM baixar quantity; a chamada HTTP à InfinitePay
  acontece FORA da transação; salva payment_link_url
- CheckoutController#create usando o service; em sucesso, redireciona para payment_url;
  em falha (sem estoque), volta ao carrinho com mensagem
- rota GET /checkout/success (redirect_url) que só mostra "recebemos seu pedido, aguardando
  confirmação" — SEM tocar em estoque
- na tela de checkout, seleção simples de entrega ("Retirada" / "Envio por app"): quando
  "Envio" estiver selecionado, renderize o discreet_shipping_note (SPEC_05); inclua também o
  secure_payment_seal. A entrega não altera valor (frete é roadmap; Uber/99 pago pelo cliente)

Specs do create_checkout_spec.rb (SPEC 04), stubbando o HTTP. Sem rede real.
```

## 10 — `feat/payment-webhook`

```
Leia SPEC_04_payment.md (passos 6–9, Payments::ProcessWebhook, controller do webhook).
Implemente:
- Webhooks::InfinitepayController#create (ActionController::Base, skip CSRF), respondendo
  em <1s com 200 {success:true} ou 400 {success:false, message:}
- Payments::ProcessWebhook: idempotência via WebhookEvent unique (provider, transaction_nsu);
  double-check chamando InfinitepayClient#payment_check; baixa ATÔMICA (transação + lock
  por variação: quantity -= qtd, reserved -= qtd); marca Order paid; marca evento processed
- InfinitepayClient#payment_check(order, payload) → POST /payment_check
- amount_matches?: aceita amount OU paid_amount >= total do pedido (tolera juros de parcela)
- extraia a rotina de baixa para Payments::SettlePaidOrder (reuso no fallback)

Cubra TODOS os casos de borda e o checklist de process_webhook_spec.rb do SPEC 04:
duplicado é no-op; paid:false não baixa; valor menor não baixa; paid_amount maior baixa;
variação zerada some do catálogo; pedido inexistente → 400. Stub de HTTP; sem sleep real.
```

## 11 — `feat/payment-fallback`

```
Leia SPEC_04_payment.md (Jobs). Implemente:
- ExpireReservationsJob: devolve reserved ao estoque de Order.stale_pending e marca expired
  (transação + lock por variação)
- ReconcilePendingPaymentsJob: para pendentes antigos, consulta payment_check; se pago,
  chama Payments::SettlePaidOrder (mesma baixa idempotente do webhook)
- agende ambos (Solid Queue recurring ou equivalente): expiração ~5min, conciliação ~10min

Specs dos dois jobs (SPEC 04): devolução de reserva, expiração, conciliação de pago,
idempotência de pedido já pago. Stub de HTTP.
```

---

## Ordem de merge e verificação

Depois de cada PR, rode a suíte inteira antes do próximo escopo. O escopo 10 (webhook) é o
mais crítico — não avance para o 11 sem os testes de idempotência e concorrência passando.

Para testar o fluxo de pagamento fim-a-fim antes de produção, use a InfiniteTag em ambiente
de teste e um túnel (ex.: ngrok) para receber o webhook localmente no `POST /webhooks/infinitepay`.
```

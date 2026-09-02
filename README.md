# Aurora

Catálogo público e painel de estoque privado, num monolito Rails.

O sistema existe para resolver um problema específico: **dar baixa no estoque quando — e
somente quando — um pagamento é confirmado**. A InfinitePay fica só como gateway de
pagamento; a gestão de estoque é nossa.

- **Catálogo** (`/`) — público, sem login.
- **Estoque** (`/admin`) — privado, com login.

A especificação completa está em [`specs/`](specs/). Comece pelo
[`SPEC_00_overview.md`](specs/SPEC_00_overview.md).

## Stack

| Camada | Escolha |
|---|---|
| Backend | Rails 7.1 (monolito) |
| Front | Hotwire (Turbo + Stimulus) + importmap |
| CSS | Tailwind (`tailwindcss-rails`) |
| Banco | PostgreSQL |
| Jobs | Solid Queue (tabelas no banco principal) |

## Requisitos

- Ruby 3.3.3 (versão fixada em `.ruby-version`)
- PostgreSQL rodando e acessível pelo usuário do sistema
- Node não é necessário: o Tailwind roda por binário e o JS usa importmap

## Setup

```bash
bundle install
bin/rails db:prepare   # cria os bancos e roda as migrations
bin/rails db:seed      # dados de desenvolvimento
```

Os seeds criam um admin de desenvolvimento: `admin@aurora.local`, senha
`trocar-isto-123` (defina `SEED_ADMIN_PASSWORD` para escolher outra). Ele entra
pelo painel em `/admin/login`. Não existe cadastro público de admin — para criar
outro, use o console.

## Rodando

```bash
bin/dev
```

Sobe três processos (via `Procfile.dev`): servidor Rails, watcher do Tailwind e o worker de
jobs do Solid Queue. A aplicação fica em <http://localhost:3000>.

Para rodar só o worker: `bin/jobs`.

## Pagamento

O fluxo real usa a InfinitePay como gateway: o checkout cria o pedido e reserva o estoque, e a
baixa definitiva só acontece quando o webhook confirma o pagamento. Ver
[`SPEC_04_payment.md`](specs/SPEC_04_payment.md).

### Modo fake (desenvolvimento sem conta na InfinitePay)

Para percorrer o fluxo inteiro sem credencial e sem rede:

```bash
INFINITEPAY_FAKE=true bin/dev
```

Com ele ligado, o `InfinitepayClient` não faz nenhuma chamada HTTP:

- `create_link` devolve uma URL para `/dev/fake_checkout?order_nsu=...`, uma página no próprio
  app que mostra o pedido e traz um botão **Simular pagamento aprovado**;
- o botão entrega o webhook em `POST /webhooks/infinitepay`, exatamente como a InfinitePay
  faria — daí para a frente o código é o de produção, sem desvio;
- `payment_check` (o double-check do webhook) responde pagamento aprovado no formato do SPEC 04,
  com o valor igual ao total do pedido.

O resto do sistema não sabe que está em modo fake. Reserva, idempotência, lock e baixa de
estoque rodam iguais.

**Em produção o modo fake nunca liga**, mesmo com `INFINITEPAY_FAKE=true` no ambiente — um
gateway simulado ali daria pedido pago sem dinheiro entrando. A rota `/dev/fake_checkout`
também não é montada fora de desenvolvimento e teste.

### Variáveis de ambiente

| Variável | Para quê | Padrão |
|---|---|---|
| `INFINITEPAY_FAKE` | Liga o gateway simulado (`true`, `1`, `yes`, `on`) | ligado em development, desligado em test, **sempre desligado em production** |
| `INFINITEPAY_HANDLE` | InfiniteTag da conta, sem o `$` | vem das credentials |
| `INFINITEPAY_BASE_URL` | Base da API do gateway | `https://api.checkout.infinitepay.io` |
| `APP_BASE_URL` | Base pública do app, usada em `redirect_url` e `webhook_url` | `http://localhost:3000` |

Em produção, `handle` e `base_url` saem das credentials (`bin/rails credentials:edit`); as
variáveis de ambiente existem para o CI e para o ambiente de teste rodarem sem a master key.

Para testar contra a InfinitePay de verdade em desenvolvimento, desligue o modo fake
(`INFINITEPAY_FAKE=false`), configure o handle e exponha o app num túnel (ngrok, por exemplo)
para o webhook chegar em `POST /webhooks/infinitepay`.

## Testes

```bash
bin/rails tailwindcss:build   # uma vez, se você ainda não rodou bin/dev
bundle exec rspec
```

RSpec é o framework de teste do projeto (o Minitest foi removido). A suíte roda no CI a cada
push e pull request — ver `.github/workflows/ci.yml`.

## Estrutura

```
app/                  código da aplicação (models, controllers, views, jobs)
config/
  queue.yml           configuração do Solid Queue (workers e dispatchers)
  recurring.yml       jobs recorrentes (expiração de reserva, conciliação)
db/migrate/           migrations
specs/                especificação do produto (SPEC 00–05 e PROMPTS.md)
spec/                 testes RSpec
```

> `specs/` (com "s") é a documentação do produto; `spec/` é a suíte de testes. Nomes
> parecidos, papéis diferentes.

## Estado atual

Escopo 1 (`feat/setup`) — só o esqueleto da aplicação. Sem models de domínio e sem telas
ainda; eles chegam nos escopos seguintes, na ordem do `SPEC_00_overview.md`.

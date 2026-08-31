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

## Rodando

```bash
bin/dev
```

Sobe três processos (via `Procfile.dev`): servidor Rails, watcher do Tailwind e o worker de
jobs do Solid Queue. A aplicação fica em <http://localhost:3000>.

Para rodar só o worker: `bin/jobs`.

## Testes

```bash
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

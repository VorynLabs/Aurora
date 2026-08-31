# SPEC 05 — Sistema de design (Aurora)

> Depende do SPEC 00. Define a identidade visual do catálogo e do painel: paleta, tipografia,
> componentes base, tom de voz e as decisões de UX específicas do nicho. É o **escopo zero do
> front**: os componentes definidos aqui são consumidos por todas as telas dos SPECs 02 e 03.
> Nada de tela de negócio aqui — só o sistema visual e os componentes reutilizáveis.

---

## Direção: "Aurora" — vinho + nude

Sofisticado, discreto e sensual sem ser vulgar. O objetivo comercial é **induzir a compra
reduzindo o constrangimento e elevando a percepção de valor**: elegante, acolhedor, confiável.
Vinho profundo transmite sensualidade e maturidade; o nude/rosé claro deixa a navegação leve
e não intimidante.

---

## Paleta (tokens Tailwind)

Definir em `tailwind.config.js` (ou `@theme` no CSS do tailwindcss-rails) como cores nomeadas.
Preferir sempre os tokens semânticos abaixo a hex solto no ERB.

| Token | Hex | Uso |
|---|---|---|
| `wine` (primária) | `#5B1A2E` | cabeçalho, botões primários, preço em destaque, links |
| `wine-dark` | `#3A0E1C` | texto sobre nude, hover de botão primário |
| `wine-ink` | `#2B1218` | quase-preto do nicho, textos fortes |
| `nude` (fundo) | `#F3E1D8` | fundo de seções, cards claros |
| `nude-deep` | `#E4C4B4` | placeholder de imagem, superfícies secundárias |
| `clay` (acento) | `#C97B5A` | detalhes, badges, realces quentes |
| `clay-text` | `#8A5240` | texto secundário sobre nude |
| `cream` | `#FBF3EE` | fundo de página (base clara) |
| `success` | `#3B6D57` | badge "em estoque", confirmações |
| `warning` | `#B07A2E` | badge "últimas unidades" |
| `danger` | `#8A2D2D` | erros, "esgotado" |

**Modo escuro (opcional, herda a lógica "Noir"):** fundo `#1A181D`, superfície `#2A2730`,
texto `#F5F2EC`, acento dourado `#E8C87E`. Não é obrigatório na v1; se implementado, via
classe `dark:` do Tailwind. Documentar mas não bloquear o lançamento por isso.

**Contraste:** todo texto sobre `wine` usa `nude`/`cream`; todo texto sobre `nude` usa
`wine-dark`/`wine-ink`. Nunca preto puro sobre nude (fica duro). Garantir AA (4.5:1) em textos.

---

## Tipografia

| Papel | Fonte | Peso | Uso |
|---|---|---|---|
| Display / títulos | **serifada elegante** (ex.: Playfair Display, Cormorant) | 500 | nome da marca, títulos de produto, headings |
| Corpo / UI | **sans humanista** (ex.: Inter, Figtree) | 400 / 500 | textos, botões, formulários, preços |

- A serifada carrega a "voz sensual/premium"; a sans mantém legibilidade e limpeza na UI.
- Dois pesos por fonte no máximo (400 e 500). Nada de 700 pesado.
- Sentence case sempre. Sem ALL CAPS (exceto siglas). Sem itálico decorativo em excesso.
- Carregar via `@font-face` self-hosted ou Google Fonts; definir `font-display: swap`.

---

## Componentes base (o que o escopo de design deve entregar)

Todos como partials/helpers reutilizáveis (ViewComponent é opcional; partials ERB bastam).
Cada um com estados: normal, hover, focus (ring visível), disabled.

| Componente | Descrição | Notas |
|---|---|---|
| `button` | primário (wine), secundário (contorno wine), texto | raio 8px; primário com hover `wine-dark` |
| `input` / `select` / `textarea` | altura ~44px, borda nude-deep, focus ring clay | usados no admin e na busca |
| `card` | superfície clara (**creme ou branco**), raio 12px, borda 0.5px, sombra sutil | base do card de produto e do card do admin. NÃO usar `nude-deep` como fundo de card — reservá-lo ao `image_placeholder`, para o card ter contraste contra o fundo da página (crítico no mobile) |
| `badge` | pílula pequena (estoque, categoria, "novo") | cores semânticas da paleta |
| `modal` | overlay escuro + painel central | novo produto (admin), confirmações |
| `dropdown` | menu de opções (admin) | acessível por teclado |
| `stepper` | seletor de quantidade − n + | limitado ao estoque; usado no detalhe |
| `flash` / `toast` | mensagens de sucesso/erro | tom breve, sem "!" gritado |
| `image_placeholder` | quando produto sem imagem | fundo nude-deep + ícone discreto |
| `image_field` | upload com **preview sempre visível** da imagem atual + botão "trocar" abaixo/sobreposto | no form de produto; no mobile o preview aparece grande, nunca só o botão |

> Todos os componentes devem funcionar bem em `turbo_frame`/`turbo_stream` (aparência correta
> mesmo durante streaming; evitar depender de JS pesado para o visual base).

---

## Layout base

- **Cabeçalho (catálogo):** faixa `wine` com nome da marca (serifada, `nude`), busca à direita,
  ícone de carrinho com contador. Enxuto.
- **Rodapé:** links institucionais discretos, **selo de pagamento seguro** (ver abaixo),
  aviso legal 18+ curto (texto, sem modal).
- **Cabeçalho (admin):** faixa `wine-ink` mais sóbria, nome do admin, logout. Sem distrações.
- Grid de catálogo: `repeat(auto-fill, minmax(180px, 1fr))`, gap generoso, respiro.
- Mobile-first: a maioria do tráfego do nicho é mobile. Testar tudo em ~380px primeiro.

---

## UX específica do nicho (decisões tomadas)

### Confirmação de idade — **não incluída**
Público já afunilado (loja física, eventos). Só um aviso textual discreto de 18+ no rodapé.
Sem modal de entrada.

### Selo de pagamento seguro — **incluído (sempre visível)**
Perto do botão de compra (detalhe e carrinho) e no rodapé: ícone de cadeado + texto curto
"pagamento seguro · Pix e cartão via InfinitePay". Universal, aumenta confiança de pagar.
Componente: `secure_payment_seal`.

### Aviso de embalagem discreta — **incluído (só no fluxo de envio)**
Aparece **apenas** quando o cliente escolhe "envio" no checkout (não o tempo todo): nota curta
"enviado em embalagem discreta, sem identificação do conteúdo". Reduz o principal medo de quem
recebe em casa. Não aparece no fluxo de "retirada". Componente: `discreet_shipping_note`,
renderizado condicionalmente pela opção de entrega.

### Fora de escopo (decididos como desnecessários)
- Modo discreto / botão de saída rápida — complexidade sem retorno para este público.
- Descritor de fatura neutro — **não é código.** É configuração no painel da InfinitePay
  (como o nome da loja aparece na fatura do cartão do cliente). Anotado aqui só como lembrete
  para o dono verificar com a InfinitePay se desejar. Não bloqueia nada no sistema.

---

## Tom de voz (microcopy)

- Acolhedor, adulto, direto. Sem duplo sentido forçado, sem vulgaridade, sem infantilizar.
- Botões: verbo curto ("Adicionar", "Comprar", "Finalizar"). Sem "Clique aqui".
- Erros: dizem o que houve e o que fazer, sem gritar. "Esse item está sem estoque. Veja
  similares." em vez de "ERRO!".
- Vazios: convidam. "Seu carrinho está vazio — explore o catálogo."
- Preço sempre em `R$ 0,00` (vírgula decimal, padrão BR).

---

## Acessibilidade

- Contraste AA em todo texto.
- Focus ring visível em todos os controles (ring clay).
- Navegação por teclado no dropdown, modal e stepper.
- `alt` descritivo nas imagens de produto (o admin preenche; se vazio, usar o título).
- Área de toque mínima 44×44px em mobile.

---

## Checklist de entrega — design system (`feat/design-system`)

- [ ] tema Tailwind com a paleta Aurora (tokens nomeados)
- [ ] fontes (serifada display + sans UI) carregadas com `font-display: swap`
- [ ] layout base do catálogo (header wine + footer com selo + aviso 18+)
- [ ] layout base do admin (header wine-ink sóbrio)
- [ ] componentes: button, input/select/textarea, card, badge, modal, dropdown, stepper,
      flash/toast, image_placeholder
- [ ] componente `image_field` (preview grande da imagem atual sempre visível + botão trocar;
      no mobile nunca mostrar só o botão)
- [ ] cards (produto e admin) em creme/branco com borda — não em nude-deep — para contraste
      no mobile
- [ ] componente `secure_payment_seal`
- [ ] componente `discreet_shipping_note` (renderização condicional preparada)
- [ ] uma página de "styleguide" interna (`/admin/styleguide` ou similar) exibindo todos os
      componentes juntos — facilita revisão visual e serve de referência para os próximos escopos
- [ ] tudo responsivo a partir de ~380px

> A página de styleguide é opcional em produção mas muito útil no desenvolvimento: um lugar
> só para ver botões, badges, cards e cores juntos e validar a identidade antes de aplicar
> nas telas reais.

module Admin::ProductsHelper
  # As colunas da listagem no desktop. Cabeçalho e linhas dividem o mesmo
  # grid-template — é isso que mantém as colunas alinhadas de uma linha para a
  # outra, já que cada linha é um grid próprio.
  #
  # Não é uma <table> de verdade porque <turbo-frame> não sobrevive dentro de
  # <tbody>: o parser joga o elemento para fora da tabela. E é o frame que
  # troca a linha pelo formulário de edição, no lugar.
  ROW_COLUMNS = "md:grid md:grid-cols-[4rem_minmax(0,2.5fr)_minmax(0,1.2fr)_8rem_5rem_5rem_7rem_2.75rem] " \
                "md:items-center md:gap-4".freeze

  # A moldura da tabela, no desktop: o raio 12px e a borda sutil dos cards do
  # design system, agora em volta de cabeçalho e linhas juntos.
  #
  # O :has(article) tira a moldura quando não há linha nenhuma — uma caixa
  # vazia em volta do "nenhum produto ainda" não diria nada — e acompanha
  # sozinho os turbo_streams que criam e removem produtos. Nada de
  # overflow-hidden: ele cortaria o menu de opções, posicionado por absolute.
  TABLE_FRAME = "md:has-[article]:rounded-card md:has-[article]:border " \
                "md:has-[article]:border-nude-deep md:has-[article]:shadow-sm".freeze

  # A última linha arredonda por baixo e dispensa o traço, que encostaria na
  # borda da moldura.
  TABLE_BODY = "md:[&>*:last-child>article]:rounded-b-card " \
               "md:[&>*:last-child>article]:border-b-0".freeze

  # Card no mobile, linha da tabela no desktop: o md: desmonta o cartão e
  # deixa só o traço que separa uma linha da outra — a borda de fora agora é
  # da moldura.
  def admin_product_row_classes
    ui_card_classes(extra: "#{ROW_COLUMNS} relative flex gap-4 p-4 md:rounded-none " \
                           "md:border-0 md:border-b md:border-nude-deep " \
                           "md:p-3 md:shadow-none")
  end

  def admin_products_header_classes
    "#{ROW_COLUMNS} hidden border-b border-nude-deep bg-nude px-3 py-2 text-sm " \
      "text-clay-text md:rounded-t-card"
  end

  def admin_products_table_classes = "mt-6 #{TABLE_FRAME}"

  def admin_products_body_classes = "space-y-3 md:space-y-0 #{TABLE_BODY}"

  # Estado do produto no catálogo, para o badge do card. A ocultação manual
  # ganha do estoque: se o admin escondeu, é isso que ele precisa ver.
  def admin_product_status(product)
    return { label: "Oculto", tone: :neutral } if product.hidden_by_admin
    return { label: "Sem estoque", tone: :warning } unless product.visible_in_catalog?

    { label: "No catálogo", tone: :success }
  end

  # Palavra que acompanha o número de variações no card do mobile. No desktop a
  # coluna tem título próprio e mostra só o número.
  def admin_variants_word(count) = count == 1 ? "variação" : "variações"
end

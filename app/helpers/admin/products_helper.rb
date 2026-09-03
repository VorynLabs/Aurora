module Admin::ProductsHelper
  # As colunas da listagem no desktop. Cabeçalho e linhas dividem o mesmo
  # grid-template — é isso que mantém as colunas alinhadas de uma linha para a
  # outra, já que cada linha é um grid próprio.
  #
  # Não é uma <table> de verdade porque <turbo-frame> não sobrevive dentro de
  # <tbody>: o parser joga o elemento para fora da tabela. E é o frame que
  # troca a linha pelo formulário de edição, no lugar.
  ROW_COLUMNS = "md:grid md:grid-cols-[4rem_minmax(0,2.5fr)_minmax(0,1.2fr)_7rem_9rem_7rem_2.75rem] " \
                "md:items-center md:gap-4".freeze

  # Card no mobile, linha da tabela no desktop: o md: desmonta o cartão e
  # deixa só as bordas que separam uma linha da outra.
  def admin_product_row_classes
    ui_card_classes(extra: "#{ROW_COLUMNS} relative flex gap-4 p-4 md:rounded-none " \
                           "md:border-0 md:border-x md:border-b md:border-nude-deep " \
                           "md:p-3 md:shadow-none")
  end

  def admin_products_header_classes
    "#{ROW_COLUMNS} hidden border border-nude-deep bg-nude/40 px-3 py-2 text-sm text-clay-text"
  end

  # Estado do produto no catálogo, para o badge do card. A ocultação manual
  # ganha do estoque: se o admin escondeu, é isso que ele precisa ver.
  def admin_product_status(product)
    return { label: "Oculto", tone: :neutral } if product.hidden_by_admin
    return { label: "Sem estoque", tone: :warning } unless product.visible_in_catalog?

    { label: "No catálogo", tone: :success }
  end

  # Estoque da coluna: soma das variações e quantas são. Curto porque divide a
  # linha com outras seis colunas.
  def admin_product_stock_summary(product)
    units = product.variants.sum(&:quantity)
    variants = pluralize(product.variants.size, "variação", plural: "variações")

    "#{units} un · #{variants}"
  end
end

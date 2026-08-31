module CatalogHelper
  # Abaixo disto o card avisa que está acabando. Empurra a decisão sem mentir:
  # o número vem do estoque disponível de verdade.
  LOW_STOCK_THRESHOLD = 3

  def catalog_low_stock?(product)
    product.variants.sum(&:available_stock) <= LOW_STOCK_THRESHOLD
  end

  def catalog_stock_label(available)
    case available
    when 0 then "Sem estoque"
    when 1 then "Última unidade"
    else "#{available} unidades disponíveis"
    end
  end

  def catalog_pill_classes(active:)
    base = "inline-flex min-h-11 shrink-0 items-center rounded-full border px-4 text-sm"

    if active
      "#{base} border-wine bg-wine text-cream"
    else
      "#{base} border-nude-deep bg-white text-wine-dark hover:bg-nude"
    end
  end
end

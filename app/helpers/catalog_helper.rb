module CatalogHelper
  # Abaixo disto o card avisa que está acabando. Empurra a decisão sem mentir:
  # o número vem do estoque disponível de verdade.
  LOW_STOCK_THRESHOLD = 3

  def catalog_low_stock?(product)
    product.variants.sum(&:available_stock) <= LOW_STOCK_THRESHOLD
  end
end

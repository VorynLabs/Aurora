module Admin::ProductsHelper
  # Estado do produto no catálogo, para o badge do card. A ocultação manual
  # ganha do estoque: se o admin escondeu, é isso que ele precisa ver.
  def admin_product_status(product)
    return { label: "Oculto", tone: :neutral } if product.hidden_by_admin
    return { label: "Sem estoque", tone: :warning } unless product.visible_in_catalog?

    { label: "No catálogo", tone: :success }
  end
end

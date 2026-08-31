class ProductsController < ApplicationController
  layout "catalog"

  # A mesma regra do catálogo vale aqui: produto oculto ou sem estoque não tem
  # página. Buscar pelo scope faz o 404 sair de graça, sem checagem extra.
  def show
    @product = Product.visible_in_catalog.find(params[:id])
    @variants = @product.variants.available.order(:price_cents, :name)
  end
end

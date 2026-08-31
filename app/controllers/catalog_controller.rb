class CatalogController < ApplicationController
  layout "catalog"

  def index
    @categories = Category.ordered
    @products = Product.visible_in_catalog
                       .includes(:variants, :category, image_attachment: :blob)
                       .order(:title)
    @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
  end
end

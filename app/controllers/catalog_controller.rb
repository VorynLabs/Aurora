class CatalogController < ApplicationController
  layout "catalog"

  def index
    @categories = Category.ordered
    @products = Product.visible_in_catalog
                       .includes(:variants, :category, image_attachment: :blob)
                       .order(:title)
    @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
    @products = search(@products, params[:q]) if params[:q].present?
  end

  private

  # sanitize_sql_like escapa % e _ digitados pelo cliente, senão eles viram
  # curinga e a busca passa a trazer o catálogo inteiro.
  def search(scope, query)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.strip)}%"

    scope.where("title ILIKE :q OR description ILIKE :q", q: pattern)
  end
end

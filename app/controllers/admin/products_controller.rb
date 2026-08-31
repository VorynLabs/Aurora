class Admin::ProductsController < Admin::BaseController
  def index
    @products = current_admin.products
                             .includes(:variants, :category, image_attachment: :blob)
                             .order(:title)
  end
end

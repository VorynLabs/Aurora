class Admin::ProductsController < Admin::BaseController
  def index
    @products = current_admin.products
                             .includes(:variants, :category, image_attachment: :blob)
                             .order(:title)
    @new_product = build_product
  end

  def new
    @product = build_product
  end

  def create
    @product = current_admin.products.new(product_params)

    if @product.save
      @new_product = build_product

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_root_path, notice: "Produto criado." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @product = current_admin.products.find(params[:id])
  end

  def update
    @product = current_admin.products.find(params[:id])

    if @product.update(product_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_root_path, notice: "Produto atualizado." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Ocultação manual: a única visibilidade que grava estado. Sumir do catálogo
  # por estoque zerado é derivado da regra do SPEC 01 e não passa por aqui.
  def toggle_visibility
    @product = current_admin.products.find(params[:id])
    @product.update!(hidden_by_admin: !@product.hidden_by_admin)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_root_path }
    end
  end

  private

  # Um produto precisa de ao menos uma variação, então o formulário já nasce
  # com uma linha.
  def build_product = current_admin.products.new(variants: [Variant.new])

  def product_params
    params.require(:product).permit(
      :title, :description, :category_id, :image,
      variants_attributes: [:id, :name, :sku, :price_reais, :quantity, :_destroy]
    )
  end
end

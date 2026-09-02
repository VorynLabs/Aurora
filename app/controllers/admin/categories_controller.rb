class Admin::CategoriesController < Admin::BaseController
  def index
    @categories = Category.ordered.left_joins(:products)
                          .select("categories.*, COUNT(products.id) AS products_count")
                          .group("categories.id")
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to admin_categories_path, notice: "Categoria criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @category = Category.find(params[:id])
  end

  def update
    @category = Category.find(params[:id])

    if @category.update(category_params)
      redirect_to admin_categories_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # O model declara `dependent: :restrict_with_error`, então destroy devolve
  # false em vez de arrastar os produtos junto. Aqui só traduzimos isso para
  # uma mensagem que diga o que fazer.
  def destroy
    @category = Category.find(params[:id])

    if @category.destroy
      redirect_to admin_categories_path, notice: "Categoria removida."
    else
      redirect_to admin_categories_path,
                  alert: "#{@category.name} tem produtos. Mova-os para outra categoria antes de remover."
    end
  end

  private

  # Só o nome: o slug sai dele no model (SPEC 01), e deixar o admin editar os
  # dois abriria caminho para slug que não combina com nome nenhum.
  def category_params = params.require(:category).permit(:name)
end

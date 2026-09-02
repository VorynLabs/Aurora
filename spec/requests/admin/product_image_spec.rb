require "rails_helper"

# Regressão do componente ui/_image_field: ele chamava url_for num anexo de
# registro ainda não salvo, e o cadastro morria com "Cannot get a signed_id for
# a new record".
RSpec.describe "Imagem do produto no admin", type: :request do
  let(:admin) { create(:admin) }
  let(:category) { create(:category) }

  let(:image) { fixture_file_upload("produto.png", "image/png") }

  def product_params(overrides = {})
    {
      product: {
        title: "Camisola de cetim",
        description: "Cetim leve",
        category_id: category.id,
        variants_attributes: {
          "0" => { name: "Preta / P", price_reais: "129,90", quantity: "4" }
        }
      }.merge(overrides)
    }
  end

  before { sign_in admin }

  describe "GET /admin/products/new" do
    it "renderiza o formulário do produto novo" do
      get new_admin_product_path

      expect(response).to have_http_status(:ok)
    end

    it "mostra o placeholder e o botão de escolher imagem" do
      get new_admin_product_path

      expect(response.body).to include("Escolher imagem")
      expect(response.body).not_to include("Trocar imagem")
    end

    it "não deixa o img sem imagem apontar para lugar nenhum" do
      get new_admin_product_path

      expect(response.body).to include('alt="Prévia da imagem do produto"')
      expect(response.body).not_to match(/<img[^>]*src=""/)
    end

    it "não vaza ERB no HTML" do
      get new_admin_product_path

      expect(response.body).not_to include("@output_buffer")
      expect(response.body).not_to include("<%")
    end
  end

  describe "POST /admin/products com imagem" do
    it "cria o produto e anexa a imagem" do
      expect { post admin_products_path, params: product_params(image: image) }
        .to change(Product, :count).by(1)

      expect(Product.last.image).to be_attached
    end

    it "redireciona para a lista, sem erro" do
      post admin_products_path, params: product_params(image: image)

      expect(response).to redirect_to(admin_root_path)
    end
  end

  # O caso que quebrava: o formulário volta com o anexo em memória, num
  # Product que nunca foi salvo.
  describe "POST /admin/products inválido, com imagem" do
    it "reexibe o formulário em vez de estourar" do
      post admin_products_path, params: product_params(title: "", image: image)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("impediram de salvar")
    end

    it "cai no placeholder, porque ainda não há URL para o anexo" do
      post admin_products_path, params: product_params(title: "", image: image)

      expect(response.body).to include("Escolher imagem")
      expect(response.body).not_to include("Trocar imagem")
    end

    it "não cria produto" do
      expect { post admin_products_path, params: product_params(title: "", image: image) }
        .not_to change(Product, :count)
    end
  end

  describe "GET /admin/products/:id/edit" do
    it "mostra o preview da imagem já salva" do
      product = create(:product, admin: admin, category: category)
      product.image.attach(io: Rails.root.join("spec/fixtures/files/produto.png").open,
                           filename: "produto.png", content_type: "image/png")

      get edit_admin_product_path(product)

      expect(response.body).to include("Trocar imagem")
      expect(response.body).to match(/<img[^>]*src="[^"]+"/)
    end

    it "cai no placeholder quando o produto salvo não tem imagem" do
      product = create(:product, admin: admin, category: category)

      get edit_admin_product_path(product)

      expect(response.body).to include("Escolher imagem")
    end
  end

  it "monta o componente sem model, como a styleguide faz" do
    get admin_styleguide_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Escolher imagem")
  end
end

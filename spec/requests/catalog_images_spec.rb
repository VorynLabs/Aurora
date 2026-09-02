require "rails_helper"

# O catálogo público tem que aguentar produto sem imagem: cadastrar imagem é
# opcional, e um anexo ausente não pode derrubar a página.
RSpec.describe "Imagens no catálogo público", type: :request do
  let(:product) { create(:product, title: "Camisola de cetim", variant_quantity: 5) }

  def attach_image(record)
    record.image.attach(io: Rails.root.join("spec/fixtures/files/produto.png").open,
                        filename: "produto.png", content_type: "image/png")
  end

  describe "produto sem imagem" do
    before { product }

    it "renderiza a listagem com o placeholder no lugar da imagem" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Camisola de cetim")
      expect(response.body).to include('aria-label="Produto sem imagem"')
    end

    it "renderiza o detalhe com o placeholder" do
      get product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('aria-label="Produto sem imagem"')
    end

    it "não emite <img> nenhuma no detalhe" do
      get product_path(product)

      expect(response.body).not_to match(/<img[^>]*rails\/active_storage/)
    end

    it "mostra o placeholder no carrinho" do
      post cart_items_path, params: { variant_id: product.variants.first.id, quantity: 1 }

      get cart_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('aria-label="Produto sem imagem"')
    end
  end

  describe "produto com imagem" do
    before { attach_image(product) }

    it "mostra a imagem na listagem, sem placeholder" do
      get root_path

      expect(response.body).to match(/<img[^>]*produto\.png/)
      expect(response.body).not_to include('aria-label="Produto sem imagem"')
    end

    it "mostra a imagem no detalhe" do
      get product_path(product)

      expect(response.body).to match(/<img[^>]*produto\.png/)
    end
  end
end

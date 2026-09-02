require "rails_helper"

RSpec.describe "Produtos do painel", type: :request do
  let(:admin) { create(:admin) }

  describe "GET /admin" do
    it "exige login" do
      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end

    context "autenticado" do
      before { sign_in admin }

      it "lista os produtos do admin" do
        create(:product, admin: admin, title: "Camisola de cetim")

        get admin_root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Camisola de cetim")
      end

      it "não mostra produto de outro admin" do
        create(:product, admin: create(:admin), title: "De outra loja")

        get admin_root_path

        expect(response.body).not_to include("De outra loja")
      end

      it "mostra também o que está fora do catálogo" do
        create(:product, admin: admin, title: "Escondido", hidden_by_admin: true)
        create(:product, admin: admin, title: "Zerado", variant_quantity: 0)

        get admin_root_path

        expect(response.body).to include("Escondido", "Zerado")
      end

      it "marca o estado de cada produto" do
        create(:product, admin: admin, title: "No ar", variant_quantity: 3)
        create(:product, admin: admin, title: "Escondido", hidden_by_admin: true)
        create(:product, admin: admin, title: "Zerado", variant_quantity: 0)

        get admin_root_path

        expect(response.body).to include("No catálogo", "Oculto", "Sem estoque")
      end

      it "mostra o estoque somado e o número de variações" do
        product = create(:product, admin: admin, variant_quantity: 4)
        create(:variant, product: product, quantity: 6)

        get admin_root_path

        expect(response.body).to include("10 unidades", "2 variações")
      end

      it "convida ao cadastro quando não há produto" do
        get admin_root_path

        expect(response.body).to include("Nenhum produto ainda")
      end
    end
  end

  describe "POST /admin/products" do
    let(:category) { create(:category) }
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

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

    it "cria o produto com as variações aninhadas" do
      expect { post admin_products_path, params: product_params }
        .to change(Product, :count).by(1)
        .and change(Variant, :count).by(1)

      product = Product.last
      expect(product.admin).to eq(admin)
      expect(product.variants.first).to have_attributes(name: "Preta / P", quantity: 4)
    end

    it "guarda o preço em centavos" do
      post admin_products_path, params: product_params

      expect(Variant.last.price_cents).to eq(12_990)
    end

    it "responde em turbo_stream inserindo o card e limpando o modal" do
      post admin_products_path, params: product_params, headers: turbo

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="prepend" target="products"')
      expect(response.body).to include('action="replace" target="new_product_modal"')
      expect(response.body).to include('action="update" target="products_count"')
      expect(response.body).to include("Camisola de cetim")
    end

    it "redireciona para a lista quando o pedido não é turbo" do
      post admin_products_path, params: product_params

      expect(response).to redirect_to(admin_root_path)
    end

    it "reexibe o formulário quando falta título" do
      expect { post admin_products_path, params: product_params(title: "") }
        .not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Title")
    end

    it "reexibe o formulário quando não há nenhuma variação preenchida" do
      params = product_params
      params[:product][:variants_attributes] = { "0" => { name: "", price_reais: "", quantity: "" } }

      post admin_products_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("produto precisa de ao menos uma variação")
    end

    it "ignora a linha de variação em branco, mas guarda as preenchidas" do
      params = product_params
      params[:product][:variants_attributes]["1"] = { name: "", price_reais: "", quantity: "" }

      post admin_products_path, params: params

      expect(Product.last.variants.count).to eq(1)
    end
  end

  describe "PATCH /admin/products/:id" do
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }
    let(:product) { create(:product, admin: admin, title: "Antigo") }

    before { sign_in admin }

    it "atualiza o produto" do
      patch admin_product_path(product), params: { product: { title: "Novo nome" } }

      expect(product.reload.title).to eq("Novo nome")
      expect(response).to redirect_to(admin_root_path)
    end

    it "atualiza a variação existente pelo preço em reais" do
      variant = product.variants.first

      patch admin_product_path(product), params: {
        product: { variants_attributes: { "0" => { id: variant.id, price_reais: "79,90" } } }
      }

      expect(variant.reload.price_cents).to eq(7_990)
    end

    it "remove a variação marcada, desde que sobre outra" do
      outra = create(:variant, product: product)
      alvo = product.variants.first

      expect {
        patch admin_product_path(product), params: {
          product: { variants_attributes: { "0" => { id: alvo.id, name: alvo.name, _destroy: "1" } } }
        }
      }.to change { product.variants.count }.from(2).to(1)

      # reload: a associação já estava carregada com a variação da fábrica.
      expect(product.reload.variants).to contain_exactly(outra)
    end

    it "responde em turbo_stream trocando o card" do
      patch admin_product_path(product), params: { product: { title: "Novo nome" } }, headers: turbo

      expect(response.body).to include(%(action="replace" target="#{ActionView::RecordIdentifier.dom_id(product)}"))
      expect(response.body).to include("Novo nome")
    end

    it "reexibe o formulário quando o título fica vazio" do
      patch admin_product_path(product), params: { product: { title: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(product.reload.title).to eq("Antigo")
    end

    it "não alcança produto de outro admin" do
      alheio = create(:product, admin: create(:admin))

      patch admin_product_path(alheio), params: { product: { title: "Invadido" } }

      expect(response).to have_http_status(:not_found)
      expect(alheio.reload.title).not_to eq("Invadido")
    end
  end

  describe "PATCH /admin/products/:id/toggle_visibility" do
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

    before { sign_in admin }

    it "oculta um produto visível" do
      product = create(:product, admin: admin, hidden_by_admin: false)

      patch toggle_visibility_admin_product_path(product)

      expect(product.reload).to be_hidden_by_admin
    end

    it "volta a mostrar um produto oculto" do
      product = create(:product, admin: admin, hidden_by_admin: true)

      patch toggle_visibility_admin_product_path(product)

      expect(product.reload).not_to be_hidden_by_admin
    end

    it "troca o card e o badge por turbo_stream" do
      product = create(:product, admin: admin, title: "Camisola", hidden_by_admin: false)

      patch toggle_visibility_admin_product_path(product), headers: turbo

      expect(response.body).to include(%(action="replace" target="#{ActionView::RecordIdentifier.dom_id(product)}"))
      expect(response.body).to include("Oculto")
      expect(response.body).to include("Mostrar no catálogo")
    end

    it "não mexe no estoque nem nas variações" do
      product = create(:product, admin: admin, variant_quantity: 5)

      expect { patch toggle_visibility_admin_product_path(product) }
        .not_to change { product.variants.sum(:quantity) }
    end

    it "não alcança produto de outro admin" do
      alheio = create(:product, admin: create(:admin), hidden_by_admin: false)

      patch toggle_visibility_admin_product_path(alheio)

      expect(response).to have_http_status(:not_found)
      expect(alheio.reload).not_to be_hidden_by_admin
    end

    it "exige login" do
      product = create(:product, admin: admin)
      sign_out admin

      patch toggle_visibility_admin_product_path(product)

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  describe "DELETE /admin/products/:id" do
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

    before { sign_in admin }

    it "apaga o produto e suas variações" do
      product = create(:product, admin: admin)
      create(:variant, product: product)

      expect { delete admin_product_path(product) }
        .to change(Product, :count).by(-1)
        .and change(Variant, :count).by(-2)
    end

    it "tira o card da lista por turbo_stream" do
      product = create(:product, admin: admin)

      delete admin_product_path(product), headers: turbo

      expect(response.body).to include(%(action="remove" target="#{ActionView::RecordIdentifier.dom_id(product)}"))
      expect(response.body).to include("0 produtos no painel")
      expect(response.body).to include("Nenhum produto ainda")
    end

    it "volta para a lista quando o pedido não é turbo" do
      product = create(:product, admin: admin)

      delete admin_product_path(product)

      expect(response).to redirect_to(admin_root_path)
    end

    it "não alcança produto de outro admin" do
      alheio = create(:product, admin: create(:admin))

      expect { delete admin_product_path(alheio) }.not_to change(Product, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "exige login" do
      product = create(:product, admin: admin)
      sign_out admin

      expect { delete admin_product_path(product) }.not_to change(Product, :count)

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  describe "GET /admin/products/:id/edit" do
    before { sign_in admin }

    it "abre o formulário do produto" do
      product = create(:product, admin: admin, title: "Camisola")

      get edit_admin_product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Camisola", "Editar produto")
    end

    it "não alcança produto de outro admin" do
      alheio = create(:product, admin: create(:admin))

      get edit_admin_product_path(alheio)

      expect(response).to have_http_status(:not_found)
    end
  end
end

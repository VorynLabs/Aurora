require "rails_helper"

RSpec.describe "Categorias no admin", type: :request do
  let(:admin) { create(:admin) }

  describe "sem login" do
    it "manda para o login" do
      get admin_categories_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  context "logado" do
    before { sign_in admin }

    describe "GET /admin/categories" do
      it "lista as categorias com quantos produtos cada uma tem" do
        vazia = create(:category, name: "Acessórios")
        com_produto = create(:category, name: "Roupas")
        create(:product, admin: admin, category: com_produto)

        get admin_categories_path

        expect(response.body).to include("Acessórios", "Roupas")
        expect(response.body).to include("1 produto")
        expect(response.body).to include("0 produtos")
      end

      it "convida a criar a primeira quando não há nenhuma" do
        get admin_categories_path

        expect(response.body).to include("Nenhuma categoria ainda")
      end
    end

    describe "POST /admin/categories" do
      it "cria a categoria e gera o slug a partir do nome" do
        expect { post admin_categories_path, params: { category: { name: "Roupas íntimas" } } }
          .to change(Category, :count).by(1)

        expect(Category.last).to have_attributes(name: "Roupas íntimas", slug: "roupas-intimas")
        expect(response).to redirect_to(admin_categories_path)
      end

      it "reexibe o formulário sem nome" do
        expect { post admin_categories_path, params: { category: { name: "" } } }
          .not_to change(Category, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("impediram de salvar")
      end

      it "recusa nome que geraria um slug já usado" do
        create(:category, name: "Roupas")

        expect { post admin_categories_path, params: { category: { name: "Roupas" } } }
          .not_to change(Category, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "não deixa o admin escolher o slug" do
        post admin_categories_path, params: { category: { name: "Roupas", slug: "outra-coisa" } }

        expect(Category.last.slug).to eq("roupas")
      end
    end

    describe "PATCH /admin/categories/:id" do
      it "atualiza o nome" do
        category = create(:category, name: "Roupas")

        patch admin_category_path(category), params: { category: { name: "Lingerie" } }

        expect(category.reload.name).to eq("Lingerie")
        expect(response).to redirect_to(admin_categories_path)
      end

      it "reexibe o formulário quando o nome fica em branco" do
        category = create(:category, name: "Roupas")

        patch admin_category_path(category), params: { category: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(category.reload.name).to eq("Roupas")
      end
    end

    describe "DELETE /admin/categories/:id" do
      it "remove a categoria vazia" do
        category = create(:category)

        expect { delete admin_category_path(category) }.to change(Category, :count).by(-1)

        expect(response).to redirect_to(admin_categories_path)
        expect(flash[:notice]).to be_present
      end

      it "barra a remoção de categoria com produtos e explica o que fazer" do
        category = create(:category, name: "Roupas")
        create(:product, admin: admin, category: category)

        expect { delete admin_category_path(category) }.not_to change(Category, :count)

        expect(response).to redirect_to(admin_categories_path)
        expect(flash[:alert]).to include("Roupas", "Mova-os")
      end

      it "não leva os produtos junto" do
        category = create(:category)
        product = create(:product, admin: admin, category: category)

        delete admin_category_path(category)

        expect(product.reload).to be_persisted
      end
    end
  end
end

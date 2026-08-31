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
end

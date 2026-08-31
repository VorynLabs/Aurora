require "rails_helper"

RSpec.describe "Styleguide", type: :request do
  it "exige login" do
    get admin_styleguide_path

    expect(response).to redirect_to(new_admin_session_path)
  end

  context "autenticado" do
    before { sign_in create(:admin) }

    it "renderiza a página" do
      get admin_styleguide_path

      expect(response).to have_http_status(:ok)
    end

    it "mostra os tokens da paleta" do
      get admin_styleguide_path

      expect(response.body).to include("wine-ink", "nude-deep", "clay-text")
    end

    it "renderiza todos os componentes do sistema de design" do
      get admin_styleguide_path

      # Um marcador por componente, para a página não perder um deles em silêncio.
      expect(response.body).to include(
        "data-controller=\"stepper\"",
        "data-controller=\"dropdown\"",
        "data-controller=\"modal\"",
        "data-controller=\"image-preview\"",
        "Pagamento seguro",
        "embalagem discreta",
        "Produto sem imagem"
      )
    end

    it "mostra as mensagens de flash pelo componente real" do
      get admin_styleguide_path

      expect(response.body).to include("Produto atualizado.")
      expect(response.body).to include("Esse item está sem estoque.")
    end
  end
end

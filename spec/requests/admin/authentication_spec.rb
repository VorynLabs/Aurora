require "rails_helper"

RSpec.describe "Autenticação do painel", type: :request do
  let(:senha) { "senha-de-teste-123" }
  let(:admin) { create(:admin, password: senha) }

  describe "acesso ao painel" do
    it "manda para o login quando não há sessão" do
      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end

    it "abre o painel para o admin autenticado" do
      sign_in admin

      get admin_root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/login" do
    it "autentica com e-mail e senha corretos" do
      post admin_session_path, params: { admin: { email: admin.email, password: senha } }

      expect(response).to redirect_to(admin_root_path)

      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "recusa a senha errada e não abre sessão" do
      post admin_session_path, params: { admin: { email: admin.email, password: "errada" } }

      # 422 e não 401: o Devise 4.9 responde erro de formulário em formato
      # navegável com unprocessable, que é o que o Turbo sabe renderizar.
      expect(response).to have_http_status(422)

      get admin_root_path
      expect(response).to redirect_to(new_admin_session_path)
    end

    it "recusa e-mail desconhecido" do
      post admin_session_path, params: { admin: { email: "ninguem@aurora.local", password: senha } }

      expect(response).to have_http_status(422)
    end
  end

  describe "DELETE /admin/logout" do
    it "encerra a sessão e o painel volta a exigir login" do
      sign_in admin

      delete destroy_admin_session_path

      expect(response).to redirect_to(new_admin_session_path)

      get admin_root_path
      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  describe "cadastro público de admin" do
    it "não tem rota" do
      get "/admin/sign_up"

      expect(response).to have_http_status(:not_found)
    end

    it "não tem sequer o helper de rota do Devise" do
      expect(Rails.application.routes.named_routes.names).not_to include(:new_admin_registration)
    end
  end

  describe "retorno ao destino original" do
    it "leva ao endereço que o admin tentou abrir antes do login" do
      get admin_root_path # guarda o destino

      post admin_session_path, params: { admin: { email: admin.email, password: senha } }

      expect(response).to redirect_to(admin_root_path)
    end
  end
end

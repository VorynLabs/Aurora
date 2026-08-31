Rails.application.routes.draw do
  # Login em /admin/login, logout em /admin/logout. Sem :registerable no model,
  # o Devise não gera rota de cadastro — não existe criação pública de admin.
  devise_for :admins,
             path: "admin",
             path_names: { sign_in: "login", sign_out: "logout" },
             controllers: { sessions: "admin/sessions" }

  namespace :admin do
    # Placeholder do painel: o escopo do CRUD troca a raiz por products#index.
    root "dashboard#index"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end

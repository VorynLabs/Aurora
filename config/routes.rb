Rails.application.routes.draw do
  # Login em /admin/login, logout em /admin/logout. Sem :registerable no model,
  # o Devise não gera rota de cadastro — não existe criação pública de admin.
  devise_for :admins,
             path: "admin",
             path_names: { sign_in: "login", sign_out: "logout" },
             controllers: { sessions: "admin/sessions" }

  namespace :admin do
    root "products#index"

    resources :products, only: %i[index new create edit update destroy] do
      member { patch :toggle_visibility }
    end

    # Referência visual interna: todos os componentes e cores numa página só.
    get "styleguide", to: "styleguide#index"
  end

  # Catálogo público, sem login.
  root "catalog#index"
  resources :products, only: %i[show]

  # Carrinho na sessão; o :id das linhas é o id da variação.
  get    "cart",           to: "cart#show"
  post   "cart/items",     to: "cart#add",    as: :cart_items
  patch  "cart/items/:id", to: "cart#update", as: :cart_item
  delete "cart/items/:id", to: "cart#remove"

  # Checkout. O GET mostra o resumo e a entrega; o POST abre o pedido e manda
  # para a InfinitePay. O success é só a página de retorno — não prova nada.
  get  "checkout",         to: "checkout#new", as: :checkout
  post "checkout",         to: "checkout#create"
  get  "checkout/success", to: "checkout#success", as: :checkout_success

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end

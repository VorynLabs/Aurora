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

    # Categoria é do catálogo inteiro, não de um admin: sem escopo por dono.
    resources :categories, except: %i[show]

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

  # Webhook da InfinitePay (passo 6 do SPEC 04). Server-to-server: sem CSRF,
  # sem sessão. É o único caminho que dá baixa em estoque.
  post "webhooks/infinitepay", to: "webhooks/infinitepay#create"

  # Checkout simulado do modo fake (INFINITEPAY_FAKE). Nunca existe em
  # produção: a rota sequer é montada lá.
  unless Rails.env.production?
    get  "dev/fake_checkout",         to: "dev/fake_checkout#show",    as: :dev_fake_checkout
    post "dev/fake_checkout/approve", to: "dev/fake_checkout#approve", as: :approve_dev_fake_checkout
    post "dev/fake_checkout/decline", to: "dev/fake_checkout#decline", as: :decline_dev_fake_checkout
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end

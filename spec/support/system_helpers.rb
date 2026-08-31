module SystemHelpers
  # No system spec o login passa pela tela, como o admin faria.
  def sign_in_as(admin, password: "senha-de-teste-123")
    visit new_admin_session_path
    fill_in "E-mail", with: admin.email
    fill_in "Senha", with: password
    click_button "Entrar"

    # Espera o login pousar. Sem isto, um `visit` logo em seguida corre com o
    # POST e chega antes do cookie de sessão.
    expect(page).to have_current_path(admin_root_path)
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end

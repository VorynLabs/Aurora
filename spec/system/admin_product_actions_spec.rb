require "rails_helper"

RSpec.describe "Ações do produto no painel", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:admin) }
  let!(:category) { create(:category, name: "Roupas") }
  let!(:product) { create(:product, admin: admin, title: "Camisola", category: category) }

  before do
    sign_in_as(admin)
    visit admin_root_path
  end

  it "abre o menu de opções do card" do
    within "##{dom_id(product)}" do
      expect(page).to have_no_link("Editar")

      click_button "Opções de Camisola"

      expect(page).to have_link("Editar")
      expect(page).to have_button("Ocultar do catálogo")
    end
  end

  it "oculta do catálogo e troca o badge sem recarregar a página" do
    within "##{dom_id(product)}" do
      expect(page).to have_content("No catálogo")
    end

    # Marca a página: se houver reload, a marca some.
    page.execute_script("window.semReload = true")

    within "##{dom_id(product)}" do
      click_button "Opções de Camisola"
      click_button "Ocultar do catálogo"

      expect(page).to have_content("Oculto")
      expect(page).to have_no_content("No catálogo")
    end

    expect(page.evaluate_script("window.semReload")).to be(true)
    expect(product.reload).to be_hidden_by_admin
  end

  it "volta a mostrar no catálogo pelo mesmo menu" do
    product.update!(hidden_by_admin: true)
    visit admin_root_path

    within "##{dom_id(product)}" do
      click_button "Opções de Camisola"
      click_button "Mostrar no catálogo"

      expect(page).to have_content("No catálogo")
    end

    expect(product.reload).not_to be_hidden_by_admin
  end

  it "remove o produto depois de confirmar" do
    within "##{dom_id(product)}" do
      click_button "Opções de Camisola"
    end

    accept_confirm(/Remover Camisola da base/) do
      within("##{dom_id(product)}") { click_button "Remover" }
    end

    expect(page).to have_no_selector("##{dom_id(product)}")
    expect(page).to have_content("Nenhum produto ainda")
    expect(page).to have_content("0 produtos no painel")
    expect(Product.count).to eq(0)
  end

  it "mantém o produto quando a confirmação é recusada" do
    within "##{dom_id(product)}" do
      click_button "Opções de Camisola"
    end

    dismiss_confirm do
      within("##{dom_id(product)}") { click_button "Remover" }
    end

    expect(page).to have_selector("##{dom_id(product)}")
    expect(Product.count).to eq(1)
  end

  it "fecha o menu com Esc" do
    within "##{dom_id(product)}" do
      click_button "Opções de Camisola"

      expect(page).to have_link("Editar")

      find("button[aria-label='Opções de Camisola']").send_keys(:escape)

      expect(page).to have_no_link("Editar")
    end
  end
end

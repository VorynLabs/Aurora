require "rails_helper"

RSpec.describe "Catálogo", type: :system do
  let!(:roupas) { create(:category, name: "Roupas") }
  let!(:acessorios) { create(:category, name: "Acessórios") }

  let!(:camisola) { create(:product, title: "Camisola de cetim", category: roupas) }
  let!(:cinta) { create(:product, title: "Cinta-liga", category: acessorios) }

  it "filtra por categoria sem recarregar a página" do
    visit root_path

    expect(page).to have_content("Camisola de cetim")
    expect(page).to have_content("Cinta-liga")

    # Marca a página: se houver reload, a marca some.
    page.execute_script("window.semReload = true")

    click_link "Roupas"

    expect(page).to have_content("Camisola de cetim")
    expect(page).to have_no_content("Cinta-liga")
    expect(page.evaluate_script("window.semReload")).to be(true)
  end

  it "busca conforme o cliente digita, sem recarregar a página" do
    visit root_path

    page.execute_script("window.semReload = true")

    fill_in "Buscar produtos", with: "camisola"

    expect(page).to have_content("Camisola de cetim")
    expect(page).to have_no_content("Cinta-liga")
    expect(page.evaluate_script("window.semReload")).to be(true)
  end

  it "mantém o cursor no campo de busca enquanto os resultados trocam" do
    visit root_path

    fill_in "Buscar produtos", with: "cinta"

    expect(page).to have_no_content("Camisola de cetim")
    expect(page.evaluate_script("document.activeElement.id")).to eq("catalog-search")
  end

  it "mantém a busca ao trocar de categoria" do
    create(:product, title: "Camisola de renda", category: acessorios)
    visit root_path

    fill_in "Buscar produtos", with: "camisola"

    expect(page).to have_content("Camisola de cetim")

    click_link "Acessórios"

    expect(page).to have_content("Camisola de renda")
    expect(page).to have_no_content("Camisola de cetim")
  end

  it "marca a categoria ativa e volta com Todos" do
    visit root_path

    click_link "Acessórios"

    expect(page).to have_content("Cinta-liga")
    expect(page).to have_no_content("Camisola de cetim")

    click_link "Todos"

    expect(page).to have_content("Camisola de cetim")
    expect(page).to have_content("Cinta-liga")
  end
end

require "rails_helper"

RSpec.describe "Categorias no painel", type: :system do
  let(:admin) { create(:admin) }

  before { sign_in_as(admin) }

  it "cria uma categoria e a encontra no select do produto novo" do
    click_link "Categorias"
    click_link "Nova categoria"

    fill_in "Nome", with: "Roupas íntimas"
    click_button "Criar categoria"

    expect(page).to have_content("Categoria criada.")
    expect(page).to have_content("Roupas íntimas")

    click_link "Produtos"
    click_button "+"

    expect(page).to have_select("Categoria", with_options: ["Roupas íntimas"])
  end

  it "leva do formulário de produto até a criação da primeira categoria" do
    click_button "+"

    expect(page).to have_content("Nenhuma categoria cadastrada")

    click_link "Crie a primeira"

    expect(page).to have_current_path(new_admin_category_path)
  end

  it "renomeia uma categoria" do
    create(:category, name: "Roupas")

    click_link "Categorias"
    click_link "Editar"

    fill_in "Nome", with: "Lingerie"
    click_button "Salvar"

    expect(page).to have_content("Categoria atualizada.")
    expect(page).to have_content("Lingerie")
  end

  it "remove uma categoria vazia" do
    create(:category, name: "Acessórios")

    click_link "Categorias"
    accept_confirm { click_button "Remover" }

    expect(page).to have_content("Categoria removida.")
    expect(page).to have_content("Nenhuma categoria ainda")
  end

  it "avisa em vez de remover categoria com produtos" do
    category = create(:category, name: "Roupas")
    create(:product, admin: admin, category: category)

    click_link "Categorias"
    accept_confirm { click_button "Remover" }

    expect(page).to have_content("Mova-os para outra categoria")
    expect(page).to have_content("Roupas")
  end
end

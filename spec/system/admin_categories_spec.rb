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

  it "cria categoria pelo modal do formulário de produto sem perder o resto" do
    create(:category, name: "Roupas")

    click_button "+"

    fill_in "Título", with: "Camisola"
    fill_in "Descrição", with: "Cetim com renda"

    click_button "Nova categoria"

    within("#new_category_modal") do
      fill_in "Nome", with: "Lingerie"
      click_button "Criar categoria"
    end

    # Modal fechado, sem recarregar: o que já estava preenchido continua lá.
    expect(page).to have_no_selector("#new_category_modal[open]")
    expect(page).to have_select("Categoria", selected: "Lingerie")
    expect(page).to have_field("Título", with: "Camisola")
    expect(page).to have_field("Descrição", with: "Cetim com renda")

    # E a categoria nova serve de verdade: o produto salva com ela.
    fill_in "Variação", with: "Preta / P"
    fill_in "Preço", with: "89,90"
    fill_in "Quantidade", with: "2"
    click_button "Cadastrar produto"

    expect(page).to have_content("Camisola")
    expect(Product.last.category.name).to eq("Lingerie")
  end

  it "mostra o erro dentro do modal, sem fechá-lo" do
    create(:category, name: "Roupas")

    click_button "+"
    click_button "Nova categoria"

    within("#new_category_modal") do
      fill_in "Nome", with: "Roupas"
      click_button "Criar categoria"

      expect(page).to have_content("Slug has already been taken")
    end

    expect(page).to have_selector("#new_category_modal[open]")
    expect(Category.count).to eq(1)
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

  it "confirma a remoção no modal, e não no alert do navegador" do
    create(:category, name: "Acessórios")

    click_link "Categorias"
    click_button "Remover"

    # Se ainda fosse o confirm nativo, o clique travaria aqui num diálogo do
    # navegador e o painel do modal nunca apareceria.
    expect(page).to have_selector("dialog[open]", text: "Remover Acessórios?")

    within("dialog[open]") { click_button "Remover categoria" }

    expect(page).to have_content("Categoria removida.")
    expect(page).to have_content("Nenhuma categoria ainda")
    expect(Category.count).to eq(0)
  end

  it "mantém a categoria quando o modal é cancelado" do
    create(:category, name: "Acessórios")

    click_link "Categorias"
    click_button "Remover"

    within("dialog[open]") { click_button "Cancelar" }

    expect(page).to have_no_selector("dialog[open]")
    expect(page).to have_content("Acessórios")
    expect(page).to have_no_content("Categoria removida.")
    expect(Category.count).to eq(1)
  end

  it "avisa em vez de remover categoria com produtos" do
    category = create(:category, name: "Roupas")
    create(:product, admin: admin, category: category)

    click_link "Categorias"
    click_button "Remover"

    within("dialog[open]") { click_button "Remover categoria" }

    expect(page).to have_content("Mova-os para outra categoria")
    expect(page).to have_content("Roupas")
    expect(Category.count).to eq(1)
  end
end

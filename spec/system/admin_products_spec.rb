require "rails_helper"

RSpec.describe "Painel de produtos", type: :system do
  let(:admin) { create(:admin) }
  let!(:category) { create(:category, name: "Roupas") }

  before { sign_in_as(admin) }

  it "abre o formulário de novo produto pelo botão flutuante" do
    expect(page).not_to have_field("Título")

    click_button "+"

    expect(page).to have_field("Título")
    expect(page).to have_field("Variação")
  end

  it "adiciona uma linha de variação sem recarregar" do
    click_button "+"

    expect(page).to have_field("Variação", count: 1)

    click_button "Adicionar variação"

    expect(page).to have_field("Variação", count: 2)
  end

  it "remove uma linha de variação que ainda não foi salva" do
    click_button "+"
    click_button "Adicionar variação"

    expect(page).to have_field("Variação", count: 2)

    within all("[data-nested-variants-target='row']").last do
      click_button "Remover variação"
    end

    expect(page).to have_field("Variação", count: 1)
  end

  it "cria o produto e insere o card na lista sem recarregar a página" do
    click_button "+"

    fill_in "Título", with: "Camisola de cetim"
    fill_in "Descrição", with: "Cetim leve"
    select "Roupas", from: "Categoria"
    fill_in "Variação", with: "Preta / P"
    fill_in "Preço", with: "129,90"
    fill_in "Quantidade", with: "4"

    click_button "Cadastrar produto"

    within "#products" do
      expect(page).to have_content("Camisola de cetim")
      expect(page).to have_content("R$ 129,90")
      expect(page).to have_content("No catálogo")
    end

    expect(page).to have_no_selector("dialog[open]")
    expect(Product.count).to eq(1)
  end

  it "mostra os erros sem fechar o painel quando falta título" do
    click_button "+"

    fill_in "Variação", with: "Preta / P"
    fill_in "Preço", with: "129,90"
    click_button "Cadastrar produto"

    expect(page).to have_content("impediram de salvar")
    expect(page).to have_selector("dialog[open]")
  end

  it "troca o card pelo formulário de edição e volta ao salvar" do
    product = create(:product, admin: admin, title: "Nome antigo", category: category)

    visit admin_root_path
    within "##{ActionView::RecordIdentifier.dom_id(product)}" do
      click_link "Editar"
      fill_in "Título", with: "Nome novo"
      click_button "Salvar alterações"
    end

    within "#products" do
      expect(page).to have_content("Nome novo")
      expect(page).to have_no_content("Nome antigo")
    end
    expect(page).to have_no_field("Título")
  end
end

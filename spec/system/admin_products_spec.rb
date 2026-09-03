require "rails_helper"

RSpec.describe "Painel de produtos", type: :system do
  let(:admin) { create(:admin) }
  let!(:category) { create(:category, name: "Roupas") }

  before { sign_in_as(admin) }

  # A tabela é feita de grid, e não de <table>: nada no HTML mostra as colunas,
  # só a medida. Cabeçalho e linha precisam bater track a track.
  def header_columns
    page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector("#products_header > div"))
        .gridTemplateColumns.split(" ")
    JS
  end

  def row_columns
    page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector("#products article")).gridTemplateColumns.split(" ")
    JS
  end

  def article_display
    page.evaluate_script(%(getComputedStyle(document.querySelector("#products article")).display))
  end

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
    expect(page).to have_content("1 produto no painel")
    expect(page).to have_no_content("Nenhum produto ainda")
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

  it "lista em tabela com colunas no desktop e em cards no mobile" do
    product = create(:product, admin: admin, title: "Camisola", category: category,
                     variant_quantity: 10, variant_price_cents: 12_990)
    create(:variant, product: product, quantity: 3, price_cents: 19_990)

    visit admin_root_path

    # As colunas pedidas pelo protótipo, na ordem.
    expect(page).to have_content("Produto")
    expect(page).to have_content("Categoria")
    expect(page).to have_content("Preço")
    expect(page).to have_content("Estoque")
    expect(page).to have_content("Status")

    row = find("##{ActionView::RecordIdentifier.dom_id(product)}")

    expect(row).to have_selector("[aria-label='Produto sem imagem']")
    expect(row).to have_content("Camisola")
    expect(row).to have_content("Roupas")
    expect(row).to have_content("R$ 129,90")
    expect(row).to have_content("13 un · 2 variações")
    expect(row).to have_content("No catálogo")
    expect(row).to have_button("Opções de Camisola")

    # Sete colunas de verdade, alinhadas com as do cabeçalho: é o que separa a
    # tabela de uma pilha de cards.
    expect(row_columns).to eq(header_columns)
    expect(row_columns.size).to eq(7)

    # No mobile a tabela some e a linha volta a ser card empilhado.
    page.current_window.resize_to(390, 900)

    expect(page).to have_no_content("Estoque")
    expect(article_display).to eq("flex")
    expect(row).to have_content("Camisola")
    expect(row).to have_content("13 un · 2 variações")
  end

  it "troca o card pelo formulário de edição e volta ao salvar" do
    product = create(:product, admin: admin, title: "Nome antigo", category: category)

    visit admin_root_path
    within "##{ActionView::RecordIdentifier.dom_id(product)}" do
      click_button "Opções de Nome antigo"
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

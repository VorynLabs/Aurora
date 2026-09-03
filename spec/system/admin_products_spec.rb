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

  # As células na ordem em que a linha as desenha, da esquerda para a direita —
  # que não é a ordem do HTML: as md:order movem estoque e variações para antes
  # do status. Os md:contents também não aparecem entre os filhos do elemento,
  # então é preciso dissolvê-los aqui.
  def columns_of(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const cells = (el) => [...el.children].flatMap((child) =>
          getComputedStyle(child).display === "contents" ? cells(child) : [child]);

        return cells(document.querySelector("#{selector}"))
          .sort((a, b) => a.getBoundingClientRect().left - b.getBoundingClientRect().left)
          .map((el) => el.innerText.trim());
      })()
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

    # As colunas do protótipo, na ordem: estoque e variações separados, e o
    # preço anunciado como "a partir" porque é o menor entre as variações.
    expect(columns_of("#products_header > div")).to eq(
      ["", "Produto", "Categoria", "Preço a partir", "Estoque", "Variações", "Status", ""]
    )

    row = find("##{ActionView::RecordIdentifier.dom_id(product)}")

    expect(columns_of("#products article")).to eq(
      ["", "Camisola", "Roupas", "R$ 129,90", "13", "2", "No catálogo", ""]
    )
    expect(row).to have_selector("[aria-label='Produto sem imagem']")
    expect(row).to have_button("Opções de Camisola")

    # Oito colunas de verdade, alinhadas com as do cabeçalho: é o que separa a
    # tabela de uma pilha de cards.
    expect(row_columns).to eq(header_columns)
    expect(row_columns.size).to eq(8)

    # No mobile a tabela some e a linha volta a ser card empilhado, onde os dois
    # números se leem juntos porque não há cabeçalho para nomeá-los.
    page.current_window.resize_to(390, 900)

    expect(page).to have_no_content("Estoque")
    expect(article_display).to eq("flex")
    expect(row).to have_content("Camisola")
    # normalize_ws porque as duas células são caixas separadas no flex do card:
    # o que as separa na tela é o gap, e no texto vira quebra de linha.
    expect(row).to have_content("13 un · 2 variações", normalize_ws: true)
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

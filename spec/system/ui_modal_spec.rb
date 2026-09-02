require "rails_helper"

RSpec.describe "Modal", type: :system do
  let(:admin) { create(:admin) }

  before do
    create(:category, name: "Roupas")
    sign_in_as(admin)
  end

  # O <dialog> modal se centra pelo `margin: auto` do user-agent, e o preflight
  # do Tailwind zera margem em tudo. Sem uma margem nossa ele encosta no canto
  # superior esquerdo — e nada no HTML denuncia isso, só a medida.
  def dialog_box
    page.evaluate_script(<<~JS)
      (() => {
        const dialog = document.querySelector("dialog[open]");
        const box = dialog.getBoundingClientRect();

        return {
          left: Math.round(box.left),
          right: Math.round(window.innerWidth - box.right),
          top: Math.round(box.top),
          bottom: Math.round(window.innerHeight - box.bottom)
        };
      })()
    JS
  end

  it "abre centralizado na tela" do
    click_button "+"

    expect(page).to have_field("Título")

    box = dialog_box
    expect(box["left"]).to be_within(2).of(box["right"])
    expect(box["top"]).to be_within(2).of(box["bottom"])
  end

  it "não encosta na borda" do
    click_button "+"

    expect(page).to have_field("Título")

    expect(dialog_box.values).to all(be_positive)
  end
end

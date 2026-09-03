# Classes dos componentes do tema Aurora. Ficam num helper, e não só em
# partials, porque botões e campos aparecem como link_to, button_to, f.submit
# ou f.text_field conforme o caso — a lista de classes é a parte reutilizável.
#
# Altura mínima 44px (min-h-11) em tudo que se toca, conforme o SPEC.
module UiHelper
  BUTTON_BASE = "inline-flex min-h-11 items-center justify-center gap-2 rounded-control " \
                "px-4 text-sm font-medium transition disabled:cursor-not-allowed " \
                "disabled:opacity-50".freeze

  BUTTON_VARIANTS = {
    primary: "bg-wine text-cream hover:bg-wine-dark",
    secondary: "border border-wine bg-transparent text-wine hover:bg-nude",
    text: "px-2 text-wine underline-offset-4 hover:text-wine-dark hover:underline",
    # Confirmação destrutiva (remover categoria, por exemplo). A paleta não tem
    # um tom escuro de danger, então o hover cai no wine-dark: mesma família,
    # mais escuro, e o texto creme continua passando AA sobre os dois.
    danger: "bg-danger text-cream hover:bg-wine-dark"
  }.freeze

  # Pílula de fundo claro com o texto na cor semântica: o badge marca o estado
  # sem gritar na linha da tabela. Cada par foi medido sobre o branco do card e
  # sobre o creme da página; o pior caso de cada um passa AA (4.5:1) para texto
  # pequeno — daí o warning-text no lugar do âmbar cheio, que ficaria em 3.3:1.
  BADGE_TONES = {
    neutral: "bg-nude-deep/50 text-clay-text",
    success: "bg-success/10 text-success",
    warning: "bg-warning/10 text-warning-text",
    danger: "bg-danger/10 text-danger",
    accent: "bg-clay/20 text-wine"
  }.freeze

  def ui_button_classes(variant: :primary, extra: nil)
    [BUTTON_BASE, BUTTON_VARIANTS.fetch(variant), extra].compact.join(" ")
  end

  def ui_input_classes(invalid: false, extra: nil)
    base = "block min-h-11 w-full rounded-control border bg-white px-3 py-2 text-sm " \
           "text-wine-ink placeholder:text-clay-text"
    [base, invalid ? "border-danger" : "border-nude-deep", extra].compact.join(" ")
  end

  def ui_badge_classes(tone: :neutral, extra: nil)
    base = "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium"
    [base, BADGE_TONES.fetch(tone), extra].compact.join(" ")
  end

  def ui_card_classes(extra: nil)
    # Fundo branco de propósito: o card precisa contrastar com o creme da
    # página, sobretudo no mobile. nude-deep fica reservado ao placeholder.
    ["rounded-card border border-nude-deep bg-white shadow-sm", extra].compact.join(" ")
  end

  def ui_label_classes = "block text-sm font-medium text-wine-dark"

  # O anexo por trás de um campo de imagem, ou nil quando não há registro
  # (a styleguide monta o componente com um form sem model).
  def ui_image_attachment(record, attribute)
    return nil unless record.respond_to?(attribute)

    attachment = record.public_send(attribute)
    attachment if attachment.respond_to?(:attached?)
  end
end

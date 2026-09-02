module Payments
  # Regra única de "o valor pago cobre o pedido?", compartilhada pelo webhook e
  # pelo job de conciliação. Os dois dão baixa a partir de um payment_check, e
  # os dois têm que aceitar exatamente os mesmos valores.
  module AmountMatching
    private

    # Tolera juros de parcelamento: o cliente pode ter pago mais que o pedido
    # (`paid_amount` > `amount`), e isso é uma venda válida. O que não vale é
    # pagar menos.
    def amount_matches?(order, check)
      check["amount"].to_i >= order.total_cents ||
        check["paid_amount"].to_i >= order.total_cents
    end
  end
end

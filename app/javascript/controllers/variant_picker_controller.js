import { Controller } from "@hotwired/stimulus"

// Troca a variação escolhida: preço, estoque exibido e o teto do stepper
// acompanham. Cada <option> carrega os próprios dados, então não há uma cópia
// do catálogo em JSON dentro da página.
export default class extends Controller {
  static targets = ["select", "price", "stock", "variantId", "stepper"]

  connect() {
    if (this.hasSelectTarget) this.select()
  }

  select() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option) return

    this.variantIdTarget.value = option.value
    this.priceTarget.textContent = option.dataset.price
    this.stockTarget.textContent = option.dataset.stockLabel
    this.stepperTarget.dataset.stepperMaxValue = option.dataset.stock
  }
}

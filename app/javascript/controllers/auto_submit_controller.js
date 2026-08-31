import { Controller } from "@hotwired/stimulus"

// Envia o formulário sozinho quando algo muda. O delay serve para digitação —
// sem ele, sairia uma requisição por tecla.
export default class extends Controller {
  static values = { delay: { type: Number, default: 0 } }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}

import { Controller } from "@hotwired/stimulus"

// A nota de embalagem discreta só aparece no fluxo de envio — quem retira no
// local não precisa dela.
export default class extends Controller {
  static targets = ["note"]

  connect() {
    this.refresh()
  }

  refresh() {
    const chosen = this.element.querySelector("input[name='delivery']:checked")

    this.noteTarget.hidden = chosen?.value !== "shipping"
  }
}

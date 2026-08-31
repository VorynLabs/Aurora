import { Controller } from "@hotwired/stimulus"

// Envolve o gatilho e o painel. Usa <dialog> nativo, que já traz foco preso
// dentro do painel e fechamento pelo Esc — sem reimplementar isso em JS.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Clicar fora do painel fecha: o clique no backdrop chega no próprio dialog.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}

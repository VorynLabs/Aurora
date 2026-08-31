import { Controller } from "@hotwired/stimulus"

// Envolve o gatilho e o painel. Usa <dialog> nativo, que já traz foco preso
// dentro do painel e fechamento pelo Esc — sem reimplementar isso em JS.
export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

  // Reabre sozinho quando o servidor devolve o painel com erros de validação.
  connect() {
    if (this.openValue) this.open()
  }

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

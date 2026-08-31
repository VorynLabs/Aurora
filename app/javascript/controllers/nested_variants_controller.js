import { Controller } from "@hotwired/stimulus"

// Adiciona e remove linhas de variação sem recarregar. O <template> guarda uma
// linha em branco com child_index NEW_RECORD, trocado por um índice único a
// cada inserção para os campos não colidirem.
export default class extends Controller {
  static targets = ["template", "list", "row"]

  add() {
    const row = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.nextIndex)
    this.listTarget.insertAdjacentHTML("beforeend", row)
  }

  remove(event) {
    const row = event.target.closest("[data-nested-variants-target='row']")
    if (!row) return

    // Variação já salva some da tela mas continua no formulário, marcada para
    // remoção; a que nunca foi salva pode sair do DOM.
    if (this.persisted(row)) {
      row.querySelector("input[name*='_destroy']").value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }

  persisted(row) {
    const id = row.querySelector("input[name$='[id]']")
    return Boolean(id && id.value)
  }

  get nextIndex() {
    return `${Date.now()}${Math.floor(Math.random() * 1000)}`
  }
}

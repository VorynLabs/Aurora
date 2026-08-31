import { Controller } from "@hotwired/stimulus"

// Mantém o preview da imagem sempre visível: ao escolher um arquivo, troca a
// imagem mostrada antes de qualquer upload.
export default class extends Controller {
  static targets = ["input", "image", "placeholder"]

  preview() {
    const file = this.inputTarget.files?.[0]
    if (!file) return

    this.revoke()
    this.objectUrl = URL.createObjectURL(file)

    this.imageTarget.src = this.objectUrl
    this.imageTarget.hidden = false
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true
  }

  disconnect() {
    this.revoke()
  }

  revoke() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }
}

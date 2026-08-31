import { Controller } from "@hotwired/stimulus"

// Seletor de quantidade preso ao estoque: maxValue vem do available_stock da
// variação. É conveniência de tela — o checkout revalida no servidor.
export default class extends Controller {
  static targets = ["input", "decrement", "increment"]
  static values = {
    min: { type: Number, default: 1 },
    max: { type: Number, default: Number.MAX_SAFE_INTEGER }
  }

  connect() {
    this.clamp()
  }

  // O teto muda quando o cliente troca de variação: a quantidade escolhida cai
  // para o novo estoque se tiver ficado alta demais.
  maxValueChanged() {
    if (this.hasInputTarget) this.clamp()
  }

  increment() {
    this.assign(this.current + 1)
  }

  decrement() {
    this.assign(this.current - 1)
  }

  clamp() {
    this.assign(this.current)
  }

  assign(quantity) {
    const wanted = Number.isFinite(quantity) ? quantity : this.minValue
    const clamped = Math.min(this.maxValue, Math.max(this.minValue, wanted))

    this.inputTarget.value = clamped
    this.inputTarget.max = this.maxValue
    this.refreshButtons(clamped)
  }

  refreshButtons(quantity) {
    if (this.hasDecrementTarget) this.decrementTarget.disabled = quantity <= this.minValue
    if (this.hasIncrementTarget) this.incrementTarget.disabled = quantity >= this.maxValue
  }

  get current() {
    return parseInt(this.inputTarget.value, 10)
  }
}

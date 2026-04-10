import { Controller } from "@hotwired/stimulus"

// Campaign editor moderation helper.
//
// - Debounced keyword-only scan as the user types (fast, no API cost)
// - Explicit "Run AI check" button for the deeper Claude scan
// - "Apply rewrite" button if the scan produced a suggestion
//
// Targets:
//   textarea — the message template field
//   output   — the div where the rendered moderation result is injected
//   csrf     — a hidden element providing the CSRF token (or we read the meta tag)
export default class extends Controller {
  static targets = ["textarea", "output"]
  static values = { url: String }

  connect() {
    this.debouncedKeywordScan = this.debounce(() => this.scanKeywordsOnly(), 500)
  }

  // Called on textarea input — fast client-side pre-check
  onInput() {
    this.debouncedKeywordScan()
  }

  // Sends the current text to /shop/moderation_preview and renders the result.
  // Called by the explicit "Run AI check" button.
  async runAiCheck(event) {
    event.preventDefault()
    if (!this.hasTextareaTarget || !this.hasOutputTarget) return

    const text = this.textareaTarget.value
    if (text.trim().length === 0) {
      this.outputTarget.innerHTML = ""
      return
    }

    this.outputTarget.innerHTML = '<div class="text-sm text-gray-500">Running moderation check...</div>'

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const formData = new FormData()
    formData.append("text", text)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken || "",
          "Accept": "text/html"
        },
        body: formData
      })
      const html = await response.text()
      this.outputTarget.innerHTML = html
    } catch (err) {
      this.outputTarget.innerHTML = `<div class="text-sm text-red-600">Scan failed: ${err.message}</div>`
    }
  }

  // Very lightweight client-side keyword hint as the user types.
  // This is NOT a replacement for the server-side scan — just a nudge.
  // Real blocking happens server-side at save/send time.
  scanKeywordsOnly() {
    // Intentionally minimal — the full scanner lives on the server.
    // Just highlight the textarea border if certain hard-flag words appear.
    const text = this.textareaTarget.value.toLowerCase()
    const redFlags = [
      "guaranteed payout", "guaranteed income", "make money fast",
      "whatsapp", "telegram", "dm me on",
      "fda approved", "miracle cure",
      "click here", "act now"
    ]
    const hit = redFlags.some(flag => text.includes(flag))
    this.textareaTarget.classList.toggle("border-red-400", hit)
    this.textareaTarget.classList.toggle("ring-1", hit)
    this.textareaTarget.classList.toggle("ring-red-200", hit)
  }

  // Replace the textarea content with the suggested rewrite.
  applyRewrite(event) {
    const rewrite = event.currentTarget.dataset.moderationRewriteValue
    if (rewrite && this.hasTextareaTarget) {
      this.textareaTarget.value = rewrite
      this.textareaTarget.dispatchEvent(new Event("input"))
    }
  }

  // Replace the textarea content with an AI-generated template.
  applyGeneration(event) {
    const text = event.currentTarget.dataset.text
    if (text && this.hasTextareaTarget) {
      this.textareaTarget.value = text
      this.textareaTarget.dispatchEvent(new Event("input"))
    }
  }

  // Call the message_generation endpoint with current campaign form context.
  async generateFromProduct(event) {
    event.preventDefault()
    if (!this.hasOutputTarget) return

    this.outputTarget.innerHTML = '<div class="text-sm text-gray-500">Generating message from product knowledge...</div>'

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const formData = new FormData()
    // Grab product_id from the form's select
    const productSelect = document.querySelector('[name="campaign[product_id]"]')
    if (productSelect) formData.append("product_id", productSelect.value)
    const nameField = document.querySelector('[name="campaign[name]"]')
    if (nameField) formData.append("campaign_name", nameField.value)
    const commField = document.querySelector('[name="campaign[commission_rate]"]')
    if (commField) formData.append("commission_rate", commField.value)
    const sampleField = document.querySelector('[name="campaign[sample_offer]"]')
    if (sampleField) formData.append("sample_offer", sampleField.checked ? "true" : "false")
    // If campaign is persisted, pass its ID
    const campaignId = this.element.dataset.campaignId
    if (campaignId) formData.append("campaign_id", campaignId)

    try {
      const genUrl = this.element.dataset.generateUrl
      const response = await fetch(genUrl, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken || "", "Accept": "text/html" },
        body: formData
      })
      const html = await response.text()
      this.outputTarget.innerHTML = html
    } catch (err) {
      this.outputTarget.innerHTML = `<div class="text-sm text-red-600">Generation failed: ${err.message}</div>`
    }
  }

  debounce(fn, wait) {
    let timer = null
    return (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => fn.apply(this, args), wait)
    }
  }
}

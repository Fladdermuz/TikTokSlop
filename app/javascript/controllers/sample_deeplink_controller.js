import { Controller } from "@hotwired/stimulus"

// Fetches the TikTok sample request deeplink from the server and renders it
// as a clickable URL and a QR code image.
//
// Values:
//   url  — the server-side deeplink endpoint (GET)
//
// Targets:
//   button  — "Generate sample link" button (disabled while loading)
//   result  — container shown after the link is fetched
//   link    — <a> tag that shows the deeplink URL
//   qr      — <img> tag that shows the QR code
//   error   — error message container
export default class extends Controller {
  static values = { url: String }
  static targets = ["button", "result", "link", "qr", "error"]

  async generate() {
    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "Generating…"
    this.errorTarget.classList.add("hidden")
    this.resultTarget.classList.add("hidden")

    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" }
      })
      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || "Failed to generate deeplink")
      }

      const url = data.url
      this.linkTarget.href = url
      this.linkTarget.textContent = url

      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(url)}`
      this.qrTarget.src = qrUrl

      this.resultTarget.classList.remove("hidden")
      this.buttonTarget.textContent = "Regenerate"
    } catch (err) {
      this.errorTarget.textContent = err.message
      this.errorTarget.classList.remove("hidden")
      this.buttonTarget.textContent = "Generate sample link"
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  copy() {
    const url = this.linkTarget.href
    navigator.clipboard.writeText(url).then(() => {
      const btn = this.element.querySelector("[data-action*='copy']")
      if (btn) {
        const original = btn.textContent
        btn.textContent = "Copied!"
        setTimeout(() => { btn.textContent = original }, 1500)
      }
    })
  }
}

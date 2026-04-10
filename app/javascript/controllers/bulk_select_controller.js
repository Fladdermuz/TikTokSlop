import { Controller } from "@hotwired/stimulus"

// Tracks selected row IDs across the page so the bulk-action bar shows a live
// count and the action buttons can submit the selection as hidden fields.
//
// Targets:
//   selectAll  — the header "select all" checkbox
//   row        — each row checkbox
//   count      — span that displays the selection count
//   bar        — the sticky action bar (hidden when selection is empty)
//   form       — the form that bulk actions submit through (so we inject hidden inputs)
export default class extends Controller {
  static targets = ["selectAll", "row", "count", "bar", "form"]

  connect() {
    this.refresh()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.rowTargets.forEach(cb => { cb.checked = checked })
    this.refresh()
  }

  toggleRow() {
    this.refresh()
  }

  refresh() {
    const selected = this.selectedIds()
    if (this.hasCountTarget) this.countTarget.textContent = selected.length
    if (this.hasBarTarget) this.barTarget.classList.toggle("hidden", selected.length === 0)
    if (this.hasSelectAllTarget && this.rowTargets.length > 0) {
      this.selectAllTarget.checked = selected.length === this.rowTargets.length
      this.selectAllTarget.indeterminate = selected.length > 0 && selected.length < this.rowTargets.length
    }
    this.syncFormHiddenInputs(selected)
  }

  selectedIds() {
    return this.rowTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  syncFormHiddenInputs(selected) {
    if (!this.hasFormTarget) return
    // Remove old hidden inputs
    this.formTarget.querySelectorAll("input[name='creator_ids[]'][type=hidden]").forEach(el => el.remove())
    // Add fresh hidden inputs
    selected.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "creator_ids[]"
      input.value = id
      this.formTarget.appendChild(input)
    })
  }

  clear() {
    this.rowTargets.forEach(cb => { cb.checked = false })
    this.refresh()
  }
}

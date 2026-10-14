// On phones every .table collapses into stacked rows (see _responsive.scss),
// which needs each cell to carry its column heading. Copies the <thead>
// labels onto the cells as data-label — on every page, and again whenever
// Turbo adds rows (frames, streams, pagination) — so no view has to.

function labelTable(table) {
  const headings = []
  table.querySelectorAll("thead tr:first-child th").forEach((th) => {
    for (let i = 0; i < th.colSpan; i++) headings.push(th.textContent.trim())
  })
  if (headings.length === 0) return

  table.querySelectorAll("tbody tr").forEach((row) => {
    let column = 0
    for (const cell of row.children) {
      if (!cell.hasAttribute("data-label") && cell.colSpan === 1) {
        cell.setAttribute("data-label", headings[column] || "")
      }
      column += cell.colSpan
    }
  })
}

function labelTables() {
  document.querySelectorAll("table.table").forEach(labelTable)
}

let scheduled = false
new MutationObserver(() => {
  if (scheduled) return
  scheduled = true
  requestAnimationFrame(() => {
    scheduled = false
    labelTables()
  })
}).observe(document.documentElement, { childList: true, subtree: true })

document.addEventListener("turbo:load", labelTables)
labelTables()

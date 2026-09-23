import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

// Draws campuses, groups, and households from server-prepared layers.
// Household points arrive already privacy-filtered (approximate unless permitted).
export default class extends Controller {
  static values = { layers: Object }

  connect() {
    const { campuses, groups, households, precise } = this.layersValue
    this.map = L.map(this.element, { scrollWheelZoom: false })
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 18,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(this.map)

    const points = []
    const add = (lat, lng, options, label) => {
      const marker = L.circleMarker([lat, lng], options).addTo(this.map)
      if (label) marker.bindTooltip(label)
      points.push([lat, lng])
    }

    households.forEach(h => {
      const label = precise ? h.name : `${h.count} household${h.count === 1 ? "" : "s"} nearby`
      add(h.lat, h.lng, { radius: precise ? 5 : 6 + Math.min(h.count, 10), color: "#f59e0b", fillOpacity: 0.5, weight: 1 }, label)
    })
    groups.forEach(g => add(g.lat, g.lng, { radius: 8, color: "#06b6d4", fillOpacity: 0.8, weight: 2 }, `${g.name} · ${g.type}`))
    campuses.forEach(c => add(c.lat, c.lng, { radius: 10, color: "#111827", fillOpacity: 0.9, weight: 2 }, c.name))

    if (points.length) {
      this.map.fitBounds(points, { padding: [24, 24], maxZoom: 14 })
    } else {
      this.map.setView([39.5, -98.35], 4)
    }
  }

  disconnect() {
    this.map?.remove()
  }
}

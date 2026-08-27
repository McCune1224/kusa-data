// Atlas visualization hook: vanilla JS SVG renderer for the map/network views.
// No external libraries, no CDN. Data is pushed from the server via the
// "atlas:data" event; clicks are pushed back via open-region / focus-player.

export const AtlasHook = {
  mounted() {
    this.pending = []
    this.raf = null
    this.nodes = []
    this.edges = []

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("width", "100%")
    svg.setAttribute("height", "100%")
    svg.setAttribute("class", "atlas-svg")
    svg.setAttribute("preserveAspectRatio", "xMidYMid meet")
    this.el.appendChild(svg)
    this.svg = svg

    this.viewBox = { w: this.el.clientWidth || 800, h: this.el.clientHeight || 520 }
    svg.setAttribute("viewBox", `0 0 ${this.viewBox.w} ${this.viewBox.h}`)

    this.handleEvent("atlas:data", (data) => {
      if (!this.svg) {
        this.pending.push(data)
        return
      }
      if (data.type === "map") this.drawMap(data.regions)
      else if (data.type === "network") this.drawNetwork(data.graph)
    })

    while (this.pending.length) {
      const data = this.pending.shift()
      if (data.type === "map") this.drawMap(data.regions)
      else if (data.type === "network") this.drawNetwork(data.graph)
    }

    this.pushEvent("request-atlas", {})
  },

  updated() {},

  destroyed() {
    if (this.raf) cancelAnimationFrame(this.raf)
    this.raf = null
    this.svg = null
    this.pending = []
  },

  clear() {
    if (!this.svg) return
    while (this.svg.firstChild) this.svg.removeChild(this.svg.firstChild)
  },

  // Equirectangular projection clipped to the lower-48 US box.
  project(lat, lng) {
    const latMin = 24, latMax = 50, lngMin = -125, lngMax = -66
    const { w, h } = this.viewBox
    const x = ((lng - lngMin) / (lngMax - lngMin)) * w
    const y = ((latMax - lat) / (latMax - latMin)) * h
    return [x, y]
  },

  drawMap(regions) {
    this.stopSim()
    this.clear()
    if (!Array.isArray(regions) || regions.length === 0) return

    const { w, h } = this.viewBox

    // Faint stylized US backdrop grid.
    const grid = document.createElementNS("http://www.w3.org/2000/svg", "g")
    grid.setAttribute("class", "atlas-backdrop")
    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    rect.setAttribute("x", "0")
    rect.setAttribute("y", "0")
    rect.setAttribute("width", String(w))
    rect.setAttribute("height", String(h))
    rect.setAttribute("fill", "rgba(28,25,23,0.4)")
    grid.appendChild(rect)
    for (let i = 1; i < 8; i++) {
      const gx = (w / 8) * i
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", String(gx))
      line.setAttribute("y1", "0")
      line.setAttribute("x2", String(gx))
      line.setAttribute("y2", String(h))
      line.setAttribute("class", "atlas-grid-line")
      grid.appendChild(line)
    }
    this.svg.appendChild(grid)

    const attendees = regions.map((r) => Math.max(1, r.attendees || 0))
    const maxA = Math.max(...attendees)
    const minA = Math.min(...attendees)

    regions.forEach((r) => {
      const [x, y] = this.project(r.lat, r.lng)
      const t = (Math.max(1, r.attendees || 0) - minA) / Math.max(1, maxA - minA)
      const radius = 6 + t * 22

      const g = document.createElementNS("http://www.w3.org/2000/svg", "g")
      g.setAttribute("class", "atlas-bubble")
      g.setAttribute("transform", `translate(${x}, ${y})`)
      g.style.cursor = "pointer"

      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      circle.setAttribute("r", String(radius))
      circle.setAttribute("class", "atlas-bubble-fill")
      g.appendChild(circle)

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("y", String(radius + 14))
      label.setAttribute("text-anchor", "middle")
      label.setAttribute("class", "atlas-label")
      label.textContent = r.label
      g.appendChild(label)

      const sub = document.createElementNS("http://www.w3.org/2000/svg", "text")
      sub.setAttribute("y", String(radius + 28))
      sub.setAttribute("text-anchor", "middle")
      sub.setAttribute("class", "atlas-label-sub")
      sub.textContent = `${r.attendees} · ${r.tournaments}`
      g.appendChild(sub)

      g.addEventListener("click", () => {
        this.pushEvent("open-region", { country: r.country, state: r.state })
      })

      this.svg.appendChild(g)
    })
  },

  drawNetwork(graph) {
    this.stopSim()
    this.clear()
    if (!graph || !Array.isArray(graph.nodes) || graph.nodes.length === 0) return

    const nodes = graph.nodes.slice(0, 160).map((n, i) => ({
      player_id: n.player_id,
      gamer_tag: n.gamer_tag,
      is_focal: !!n.is_focal,
      weight: n.weight || 1,
      x: this.viewBox.w / 2 + (Math.random() - 0.5) * 200,
      y: this.viewBox.h / 2 + (Math.random() - 0.5) * 200,
      vx: 0,
      vy: 0,
      _i: i
    }))

    const idToNode = {}
    nodes.forEach((n) => (idToNode[n.player_id] = n))

    const edges = (graph.edges || [])
      .filter((e) => idToNode[e.source] && idToNode[e.target])
      .map((e) => ({ source: idToNode[e.source], target: idToNode[e.target], weight: e.weight || 1 }))

    this.nodes = nodes
    this.edges = edges

    // Edges layer first (behind nodes).
    const edgeLayer = document.createElementNS("http://www.w3.org/2000/svg", "g")
    edgeLayer.setAttribute("class", "atlas-edges")
    this.svg.appendChild(edgeLayer)
    edges.forEach((e) => {
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("class", "atlas-edge")
      e.el = line
      edgeLayer.appendChild(line)
    })

    // Nodes layer.
    const nodeLayer = document.createElementNS("http://www.w3.org/2000/svg", "g")
    nodeLayer.setAttribute("class", "atlas-nodes")
    this.svg.appendChild(nodeLayer)
    nodes.forEach((n) => {
      const g = document.createElementNS("http://www.w3.org/2000/svg", "g")
      g.setAttribute("class", n.is_focal ? "atlas-node atlas-node-focal" : "atlas-node")
      g.style.cursor = "pointer"

      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      circle.setAttribute("r", n.is_focal ? "14" : "8")
      circle.setAttribute("class", "atlas-node-fill")
      g.appendChild(circle)

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("y", n.is_focal ? "28" : "20")
      label.setAttribute("text-anchor", "middle")
      label.setAttribute("class", "atlas-label")
      label.textContent = n.gamer_tag
      g.appendChild(label)

      g.addEventListener("click", () => {
        this.pushEvent("focus-player", { id: String(n.player_id) })
      })

      n.el = g
      nodeLayer.appendChild(g)
    })

    this.alpha = 1
    this.tick()
  },

  tick() {
    const { w, h } = this.viewBox
    const nodes = this.nodes
    const k = 0.04 * this.alpha

    // Repulsion between every pair.
    for (let i = 0; i < nodes.length; i++) {
      const a = nodes[i]
      for (let j = i + 1; j < nodes.length; j++) {
        const b = nodes[j]
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dist = Math.sqrt(dx * dx + dy * dy) || 0.01
        const force = (2400 / (dist * dist)) * this.alpha
        const fx = (dx / dist) * force
        const fy = (dy / dist) * force
        a.vx += fx
        a.vy += fy
        b.vx -= fx
        b.vy -= fy
      }
    }

    // Spring attraction along edges.
    this.edges.forEach((e) => {
      const a = e.source
      const b = e.target
      let dx = b.x - a.x
      let dy = b.y - a.y
      let dist = Math.sqrt(dx * dx + dy * dy) || 0.01
      const target = 90
      const force = (dist - target) * 0.02 * k * (e.weight || 1)
      const fx = (dx / dist) * force
      const fy = (dy / dist) * force
      a.vx += fx
      a.vy += fy
      b.vx -= fx
      b.vy -= fy
    })

    // Centering + integration with damping.
    nodes.forEach((n) => {
      n.vx += (w / 2 - n.x) * 0.008 * this.alpha
      n.vy += (h / 2 - n.y) * 0.008 * this.alpha
      n.vx *= 0.85
      n.vy *= 0.85
      n.x += n.vx
      n.y += n.vy
      n.x = Math.max(20, Math.min(w - 20, n.x))
      n.y = Math.max(20, Math.min(h - 20, n.y))
      if (n.el) n.el.setAttribute("transform", `translate(${n.x}, ${n.y})`)
    })

    this.edges.forEach((e) => {
      if (!e.el) return
      e.el.setAttribute("x1", String(e.source.x))
      e.el.setAttribute("y1", String(e.source.y))
      e.el.setAttribute("x2", String(e.target.x))
      e.el.setAttribute("y2", String(e.target.y))
    })

    this.alpha *= 0.985
    if (this.alpha > 0.02) {
      this.raf = requestAnimationFrame(() => this.tick())
    } else {
      this.raf = null
    }
  },

  stopSim() {
    if (this.raf) cancelAnimationFrame(this.raf)
    this.raf = null
    this.alpha = 0
  }
}

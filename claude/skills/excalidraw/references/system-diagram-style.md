# House Style — System & Architecture Diagrams

Copy-paste reference for the mandatory system-diagram format described in
`SKILL.md → House Style: System & Architecture Diagrams`.

Derived from a validated pair of production diagrams (Bevri RBAC, Aug 2026):
an **explainer** board ("How the RBAC System Works") plus a **system** board
("RBAC — System Diagram"). Numbers below are the actual values from those files.

---

## 1. Canvas anatomy (top → bottom)

```
┌───────────────────────────────────────────────────────────────────────┐
│  Title            hand-drawn font, 42px, #111827                      │  y ≈ 40
│  One-line subtitle  normal font, 17px, #868e96                        │  y ≈ 100
│                                                                       │
│  ┌─ CONCEPT STRIP ─────────────────────────────────────────────────┐  │  y ≈ 174
│  │ 1. Concept A   │ 2. Concept B   │ 3. Concept C                  │  │  (explainer board)
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌ ZONE ─┐   ┌ ZONE ────────┐   ┌ ZONE ──────┐   ┌ ZONE ─────────┐    │  y ≈ 340–950
│  │people │──►│ browser      │──►│ compute    │──►│ managed data  │    │  main flow
│  └───────┘   └──────────────┘   └────────────┘   └───────────────┘    │
│                                                                       │
│  ┌ LEGEND ──────┐  ┌ READ PATH ────────┐  ┌ WRITE PATH ───────────┐   │  y ≈ 1070
│  │ shape → what │  │ 1..8 numbered      │  │ A..D lettered        │   │
│  └──────────────┘  └────────────────────┘  └──────────────────────┘   │
│                                                                       │
│  ▓ One-sentence thesis banner, full width, red ▓                      │  y ≈ 1580
└───────────────────────────────────────────────────────────────────────┘
```

Overall canvas: ~2600 × 1650 for a system board. Do not compress it — this
format is meant to be read zoomed-to-fit on a laptop, then zoomed into.

---

## 2. Element vocabulary

| Meaning | Element | Fill | Stroke |
|---|---|---|---|
| Service / middleware | `rectangle`, `roundness: {type: 3}` | role color | role color |
| Data store / cache | **cylinder** (3 elements, see §4) | `#99e9f2` cache / `#b2f2bb` db / `#ffc9c9` broker | `#0c8599` / `#2f9e44` / `#e03131` |
| Network edge (TLS, LB, gateway) | `diamond` | `#e9ecef` | `#1e1e1e` |
| Human actor | ellipse head + 4 `line` limbs, label 14px below | transparent | `#1e1e1e` (user) / `#9c36b5` (admin) |
| Trust boundary / zone | `rectangle`, `strokeStyle: "dashed"`, `backgroundColor: "transparent"`, `roundness: {type: 3}` | transparent | zone color |
| Step badge | `ellipse` 34×34 | `#ffec99` | `#f08c00`, text `#f08c00` 15px |
| Terminal / failure | `rectangle` | `#ffc9c9` | `#e03131` |

**Never fill a zone.** Trust boundaries are transparent + dashed so the shapes
inside stay legible. Zone label goes *above* the frame's top edge
(`y = frame.y - 34`), in the frame's stroke color, hand-drawn font, 20px.

---

## 3. Arrow grammar (declare it in the legend, then never deviate)

| Style | Color | Means |
|---|---|---|
| solid | `#1e1e1e` | synchronous request |
| solid | `#2f9e44` | data returned / success path |
| solid | `#9c36b5` | admin / write path |
| dotted | `#0c8599` | cache read |
| dashed | `#e03131` | async fan-out, invalidation, or deny |

Arrow labels stay tiny — 12px, in the arrow's own color (`read`, `on miss`,
`deny`, `publish`, `clear`).

---

## 4. Cylinder recipe (there is no cylinder primitive)

Three elements, same fill and stroke, in this order:

```json
[
  {"type":"ellipse","id":"db-top","x":1560,"y":330,"width":220,"height":50,
   "backgroundColor":"#b2f2bb","strokeColor":"#2f9e44","roughness":1},
  {"type":"rectangle","id":"db-body","x":1560,"y":355,"width":220,"height":150,
   "backgroundColor":"#b2f2bb","strokeColor":"#2f9e44","roughness":1},
  {"type":"ellipse","id":"db-bot","x":1560,"y":480,"width":220,"height":50,
   "backgroundColor":"#b2f2bb","strokeColor":"#2f9e44","roughness":1}
]
```

Bind arrows to `db-body`. Put the label as a standalone `text` centered on the
body, not as a bound container label (the ellipses would fight it).

---

## 5. Fonts

| `fontFamily` | Use for |
|---|---|
| `1` (hand-drawn) | Board title, zone labels — and nothing else |
| `2` (normal) | Every box label, every body sentence |
| `3` (code) | Legend rows and numbered path lists, so columns line up |

`roughness: 1` on every shape in a system diagram. The sketch look is
deliberate: it reads as "a thing a human drew to explain something", which is
exactly the reception you want in a review thread.

---

## 6. Legend + path panels (bottom row)

Three panels, each a rounded rectangle with a hand-drawn 20px label above it:

- **LEGEND** — one row per shape/arrow convention used. Row = rounded rect
  340×46, filled with the thing it describes (a cyan row for the cyan cylinder,
  a red-dashed row for the red dashed arrow) so the legend *demonstrates* rather
  than describes.
- **READ PATH** — the numbered walkthrough, monospace, two columns:
  `1 open a page      5 cache hit  -> answer`
- **WRITE PATH** — the lettered walkthrough, monospace, same treatment.

The badge numbers in the panels must match the ①..⑧ / Ⓐ..Ⓓ badges dropped on
the flow above. That pairing is what makes the diagram self-teaching.

---

## 7. Thesis banner

The last element is a full-width rectangle (e.g. 2560×49) holding one sentence,
red stroke and red 20px text, that states the invariant the whole diagram
exists to establish:

> The browser hides. The API decides. Postgres holds the truth.

If you cannot write this sentence, you have not understood the system well
enough to draw it.

---

## 8. The explainer board (companion diagram)

The system board is for engineers. Pair it with an explainer board for product
and QA:

- Concept strip: 3 boxes, each a *reader's question*, not a component name
  ("1. Your level", "2. Your permissions", "3. Your job title").
- Lifecycle strip: 5 boxes left→right in caps
  (`SIGN IN → LOAD SCREEN → SEND REQUEST → SERVER CHECKS → SCOPED RESULT`),
  each with 3–4 short lines under the heading.
- Bottom strip: the "so what" boxes — what changes at runtime, who may manage
  whom, and the one security rule. Amber/yellow fills to separate them from the
  flow.

---

## 9. Pre-flight checklist

- [ ] Every body line fits inside its box with ≥20px right margin (measure:
      `chars × fontSize × 0.6`). Clipped sentences are the #1 defect.
- [ ] Zone labels do not collide with the frame border or any child shape.
- [ ] Every arrow style used appears in the legend, and vice versa.
- [ ] Every badge on the flow has a matching row in a path panel.
- [ ] The thesis banner exists and is true.
- [ ] Anything not yet enforced is labelled as such (see SKILL.md rule 11).

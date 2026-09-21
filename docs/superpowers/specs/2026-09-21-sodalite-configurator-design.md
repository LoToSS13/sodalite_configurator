# Sodalite Configurator — design

**Date:** 2026-09-21  
**Status:** draft for review  
**Repo:** `/Users/alekseizubankov/Development/Gems/sodalite-configurator`  
**Companion:** Flutter web, offline, no Consul, no Jasper

## Goal

Give analysts and developers a UI that can only produce JSON the Sodalite `configurable_module` stack will accept. The user never places keys in JSON. They fill fields and add blocks only in schema-defined slots. Export stays disabled until the module is complete.

Success: a zip `apps/{slug}/` that `configurable_module` can load, without hand-editing JSON, and without states that today’s parsers would silently drop.

## Non-goals (v1)

- Publish or read Consul
- Live Jasper (XSD catalog, entity aliases, path autocomplete from server)
- SVG upload; icon fields are Consul path strings (`apps/{slug}/resources/….svg`)
- Global files: `configuration.json`, `compatibility.json`, `feature_flags.json`
- Legacy modules that only ship `additional_layers/{module}_layers_configuration.json`
- Hand-editing JSON (preview is read-only so rules cannot be bypassed)
- Depending on `sodalite_platform` (too heavy for web; parsers silently drop invalid optional nodes)

## Users and UX contract

Primary UI is a form of nested blocks. JSON preview is optional and read-only. Labels in Russian; exported JSON keys match Consul (English, as in the app).

## Artifact

One product type in v1: **configurable module pack**.

Zip layout (files omitted when the matching feature is off):

```
apps/{slug}/
  app.json                 # always
  base_layer.json          # always
  additional_layers.json   # always; may be `[]`
  object_creation.json     # only if «создание объектов» включено
  search.json              # only if «поиск» включён
```

`slug` is the Consul folder name: `^[a-z0-9][a-z0-9_-]*$`. It is not stored inside the JSON files; it is the directory name.

`app.json`:

```json
{ "title": "…", "subtitle": "…" }
```

Both strings required and non-empty. `roleAlias` is derived by the app (`mobile_map:{slug}`), not exported.

## Architecture

Schema-driven document, not a set of one-off screens.

```
UI (Flutter web)
  → DocumentController  (tree + selection + completeness)
  → Schema              (node types, fields, slots, constraints)
  → Codec               (tree ↔ JSON / zip)
```

`sodalite_platform` is the **reference**, not a runtime dependency. Schema and codec are written to match parsers under `modules/sodalite_platform/lib/{layer_configuration,object_creation_configuration,search_configuration,module_configuration}`. Configurator is **stricter**: anything those parsers would drop or ignore is a blocking error here, except the documented import conversions below.

### Schema units

- **NodeType** — id, fields, slots, JSON mapping (object vs array vs wrapped `{ content }`).
- **FieldSpec** — key, kind (`string`, `nonEmptyString`, `bool`, `int`, `enum`, `color`, `stringMap`, `stringList`), required flag, constraints, default for new nodes.
- **SlotSpec** — key, cardinality (`one` | `optionalOne` | `list`), allowed child NodeType ids, whether the slot must be filled for the parent to be complete.
- **Constraint** — per-field (regex, min/max, enum) or cross-node (at-least-one of view/rule, placeholder keys ⊆ `paths` or `endpoints`, unique keys).

UI does not know Consul shape. It renders fields and slot «+» menus from Schema. Adding a block instantiates a child NodeType in that slot. Removing a block removes the subtree.

### Document

A tree of `Node { id, type, fields, childrenBySlot }`. Root is `ModuleBundle`. Validation walks the tree and produces a list of `Issue { nodeId, path, message, severity: error }`. Completeness = zero errors. Warnings exist only for import (unknown keys dropped); they do not block export once the tree is valid.

### Why not JSON Schema / not platform parsers

JSON Schema is a poor fit for slot «add one of these types» and for discriminated unions (action `type`, search filter operators). Platform `fromJson` methods drop bad optional items; the configurator must refuse them. A Dart schema DSL in this repo is the source of truth for the UI. Later, golden JSON from this repo can be parsed in Sodalite tests to catch drift.

## UI

### Home

- Создать модуль (задать slug)
- Открыть zip или набор JSON-файлов
- Список черновиков из `localStorage` (title + slug + last edited)

### Editor: document of blocks

Single canvas for the whole module (not file tabs, not IDE three-pane).

Top bar: slug, count of blocking issues, toggle «JSON», button «Скачать zip» (disabled while issues > 0).

Main column, top to bottom:

1. Card **Карточка модуля** (`app.json`) — title, subtitle.
2. Card **Базовый слой** — nested `geo` (required) and slot «+ info».
3. Dashed slot **+ дополнительный слой** (same Layer node type; exported as array).
4. Two dashed feature slots: **включить создание объектов**, **включить поиск**. Off → no card, no file in zip. On → card appears; turning off removes the subtree after confirm.

Right column: completeness list. Click an issue to select/scroll to the node. JSON panel is closed by default; when open it occupies the right column (completeness remains as a summary in the top bar). JSON is generated from the current tree, read-only, not a second source of truth.

Nested cards are slots. Each slot’s «+» menu lists only allowed NodeTypes. Empty required slots and empty required fields are marked as errors on the card.

### Persistence

Autosave the document (serialized tree, not raw JSON) to `localStorage` keyed by slug. Refresh restores the draft. Export zip does not clear the draft.

## Node catalog

Legacy `info.fields` at the layer-info root, `info.preview`, and `info.acceptance` are not authorable. On import, `info.fields` becomes one untitled `infoSection`; `preview` / `acceptance` are dropped with a warning.

### ModuleBundle

| Slot / field | Cardinality | Notes |
|---|---|---|
| `slug` | required field | Directory name; not a JSON key |
| `app` | one | App |
| `baseLayer` | one | Layer, exported as object |
| `additionalLayers` | list | Layer, exported as array (empty allowed) |
| `objectCreation` | optionalOne | Feature toggle |
| `search` | optionalOne | Feature toggle; if present, at least one SearchObject |

### App

| Field | Required | Export |
|---|---|---|
| `title` | yes, non-empty | `title` |
| `subtitle` | yes, non-empty | `subtitle` |

### Layer

| Slot | Cardinality |
|---|---|
| `geo` | one, required |
| `info` | optionalOne |

### Geo

| Field | Required | Notes |
|---|---|---|
| `alias` | yes | Jet layer alias, non-empty string |
| `name` | no | |
| `visibilityThreshold` | no | If set: integer 15, 16, or 17; else omit |
| `hasMarkers` | yes in UI | Initial: `true` on base layer, `false` on additional. Always exported. |
| `showTagInCluster` | yes in UI | Same defaults as `hasMarkers`. Always exported. |
| `style` | optional group | If present, both `color` (`#RRGGBB` or `#RRGGBBAA`) and `isDashed` (bool) required. `isOutlined` is a platform default and is not authored or exported. |

Slot `sources`: list of GeoSource.

### GeoSource

| Field | Required | Notes |
|---|---|---|
| `name` | no | |
| `icon` | no | Consul SVG path string |
| `style` | optional group | Same rule as Geo.style |
| `view` | no | Non-empty Jet view alias |
| `rule` | no | `{ operator, property, value }` |

At least one of `view` (non-empty) or a valid `rule` is required. Both may be set (the app uses `view ?? layer.alias` and applies `rule` separately). A source with neither is an error (the app would drop it).

`rule.operator` ∈ `eq`, `noteq`, `isnotnull`, `isnull`, `notin`. `property` is required. `value` is required and non-empty for `eq`, `noteq`, `notin`; for null checks the UI hides `value` and export writes `""` (platform always stores a string).

### Info

| Field | Required | Notes |
|---|---|---|
| `alias` | yes | Jasper entity alias |
| `paths` | no | `Map<String,String>`, keys unique, values non-empty |
| `title`, `subtitle`, `status` | no | Stored as `{ content }`. Placeholders `{Key}` in content must be keys of `paths`. |
| `additionalTitle` | no | plain string |

Slots: `infoSections` (list), `images` (list), `attachments` (list), `inspectionView` (list), `actions` (list). All optional; empty lists omitted from JSON.

Media `paths` convention: keys used as image sources must start with `Image_`; attachment sources with `Attachments_`. The platform splits these prefixes out of the general `paths` map at parse time. The configurator keeps one `paths` map in the UI and still exports a single `info.paths` object, same as Consul.

### InfoSection

| Field | Required |
|---|---|
| `title` | no |
| `fields` | list, at least one FieldRow |

### FieldRow

| Field | Required | Notes |
|---|---|---|
| `name` | yes | |
| `content` | yes | Placeholders ⊆ `paths` of the enclosing Info |
| `separator` | no | |
| `url` | no | |
| `ifTrue` / `ifFalse` | no | |

### MediaSection (images / attachments)

| Field | Required | Notes |
|---|---|---|
| `title` | no | |
| `sources` | yes, non-empty | Each value is a key in `paths` with the right prefix |
| `extensions` | attachments only, optional | If omitted: no filter. If present: list of strings; empty list is valid (show nothing). Any token that normalizes to empty is an error (the app would drop the section). |

### InspectionTab

| Field / slot | Required | Notes |
|---|---|---|
| `tabName` | no | |
| `processName` | no | |
| `objects` | yes | Map of pathKey → InspectionObject; at least one entry. Keys must exist in Info.paths. |
| `creation` | optionalOne | InspectionCreation |

### InspectionObject

| Field | Required |
|---|---|
| `endpoints` | yes, non-empty string map |
| `title.content` | yes; `{Ident}` placeholders must be keys of this object’s `endpoints` (the app rewrites them to `{pathKey_endpointKey}` at parse) |
| `subtitle` | no, `{ content }`; same placeholder rule |
| `tag` | optional `{ color, content, ifTrue? }` |
| `fields` | list of FieldRow |
| `images` | optional `{ source }` pointing at an Image_ path |
| `attachments` | optional `{ source, extensions? }` |

### InspectionCreation

| Field | Required | Notes |
|---|---|---|
| `title` | yes | |
| `xsdPath` | yes | Opaque Jasper XSD id/path string |
| `relateToObjectKey` | yes | |
| `condition` | no | |
| `requireDateWatermark` | yes in UI | Default `true`, always exported |
| `saveToGallery` | yes in UI | Default `false`, always exported |

### Action (discriminated)

«+ действие» offers two types only.

**informationChange:** `xsdPath` required.

**geometryChange:** `xsdPath` required; `geometryTypes` required non-empty list of `point` | `line` | `polygon`.

Unknown `type` cannot be created and fails import as an error node.

### ObjectCreation (feature)

| Field | Required | Notes |
|---|---|---|
| `xsdPath` | yes | Opaque string |
| `geometryTypes` | no | If present, non-empty; item `{ type, autoMode? }` with `autoMode` allowed only for `point` |
| `requireDateWatermark` | yes in UI | Default `true` |
| `saveToGallery` | yes in UI | Default `false` |
| `style` | optional | `color?`, `iconPath?` (Consul SVG path) |

### Search (feature)

| Field | Required |
|---|---|
| `placeholder` | no |

Slot `searchObjects`: list, **at least one** SearchObject.

### SearchObject

All of the following required or the object is incomplete (the app would drop it):

| Field | Constraint |
|---|---|
| `alias` | non-empty |
| `objectKeyFieldPath` | non-empty |
| `paths` | non-empty string map |
| `attribute` | non-empty, must not contain `/` |
| `resultView` | object of strings: `title` required non-empty; `subtitle1` / `subtitle2` optional non-empty strings (not `{ content }` wrappers) |
| `alternativePositionObject` | optional; if present both `jetAlias` and `keyField` required |
| `filter` | optional; if present must be a **group** (see below). Invalid filter is an error (the app would drop the whole SearchObject). |

`objectAlias` is derived by the app from `objectKeyFieldPath` / `alias`. Do not export it.

### SearchFilter

Consul search.json uses a different leaf shape than Jasper `toJson()`. Export **Consul** shape so `SearchFilterNode.fromJson` accepts it.

Root of `filter` must be a group (platform `SearchBody.fromJson` rejects a lone leaf):

```json
{ "operator": "and" | "or", "criterions": [ /* ≥ 1 child */ ] }
```

Children are groups or leaves. Unknown `operator` is an import error.

Leaf (Consul):

```json
{ "operator": "<op>", "alias": "<field>", "value": … }
```

| Operator | `value` |
|---|---|
| `eq`, `noteq`, `like`, `notlike`, `gt`, `lt`, `gte`, `lte` | required string |
| `in`, `notin` | required non-empty array of strings |
| `empty`, `notempty` | omit `value` |

Do not emit Jasper `{ "property": { "alias", "type": "field" } }` in search.json. The app parser does not read that form from Consul.

## Validation vs platform parsers

| Platform behavior | Configurator |
|---|---|
| Missing optional node omitted | Slot empty is valid when optional |
| Invalid optional item dropped | Item is an error; export blocked |
| `additional_layers` object or array | Import normalizes object → one-element array; export always array |
| `showTagInCluster` / `hasMarkers` omitted → kind-specific default | UI always has a value; export always writes bool |
| `info.fields` legacy | Import → one InfoSection; cannot author root `fields` |
| `preview` / `acceptance` ignored | Import warning, dropped, not re-exported |
| Extra unknown keys ignored | Import warning, dropped, not re-exported |
| Search object missing a required field → dropped | SearchObject incomplete → error |
| Attachment `extensions` invalid → section dropped | Error on that MediaSection |

Export walks Schema and emits **only** known keys. No `_meta` in Consul files.

Placeholder check: `{Ident}` in template strings must match a key in the relevant `paths` map. Unmatched placeholder is an error.

## Import

Accepted inputs:

- Zip containing `apps/{slug}/*.json` (extra files ignored with warning)
- Zip or folder whose JSON files are named `app.json`, `base_layer.json`, `additional_layers.json`, `object_creation.json`, `search.json` (slug taken from parent folder or asked if missing)
- A single one of those files (opens a module with only that part filled; completeness will fail until the rest is added)

Failed parse of a file: that file is not applied; a message names the file and the failure. Other files in the zip still apply.

After import the document may be invalid; the user fixes it in the UI. Export stays blocked until complete.

## Export

Disabled until completeness is empty. Builds zip with `archive` (or equivalent) in the browser and triggers download: `{slug}-sodalite-module.zip`. JSON encoding: 2-space indent, UTF-8, object key order stable (schema field order) so diffs are readable.

Incomplete JSON preview (when the panel is open before export is allowed) still uses the codec but may omit invalid optional children and render required empty strings as `""` so the structure is visible. This preview is not downloadable as the official zip.

## Flutter web project

Single app (no extra packages in v1):

```
sodalite-configurator/
  lib/
    schema/       # NodeType, FieldSpec, SlotSpec, catalog for the module pack
    document/     # Node tree, DocumentController, completeness
    codec/        # JSON encode/decode per node, zip import/export
    persistence/  # localStorage drafts
    ui/
      home/
      editor/     # canvas, block card, slot add, completeness, json preview
  test/
    schema/
    codec/
    document/
    ui/
  docs/superpowers/specs/
```

Renderer: HTML (form-heavy; no custom shaders). State: `ChangeNotifier` + immutable document updates. No BLoC.

`xsdPath`, Jasper aliases, and Jet aliases are plain validated strings. No network.

## Testing

- Schema: each NodeType has required/optional/at-least-one-of cases.
- Codec: round-trip of a full valid module; golden files compared as parsed maps.
- Import conversions: legacy `fields` → section; extra keys warned; object `additional_layers` → array.
- Completeness: export eligibility false until required fields/slots filled; feature-off omits files.
- Widget tests: slot «+» offers only allowed types; zip button disabled with issues; JSON preview has no TextField.
- No dependency on a running Consul/Jasper.

Follow-up (not this repo’s v1 gate): feed goldens through `LayerConfigurationParser` / object-creation / search parsers in `sodalite_platform` tests to detect schema drift.

## Error handling

- Import I/O or JSON syntax: dialog, document unchanged for that file.
- Corrupt localStorage draft: ignore that entry, stay on home.
- Zip download API failure: show message, keep document.

## Implementation slices (still one product)

The catalog is large. Ship the product only when all slices below exist. Implementation order:

1. Schema engine, App + Geo Layer, zip download, new module, completeness, Russian UI shell.
2. Info: paths, titles, sections, media, placeholder checks.
3. inspectionView + actions.
4. ObjectCreation + Search (including filter tree).
5. Import zip/files, drafts, JSON preview.

## Open decisions that are closed

- Output: download + import; no Consul.
- Jasper: offline strings only.
- Layout: document of blocks, not tabs, not IDE panes.
- Optional files: feature toggles, not always-visible empty cards.
- JSON: toggle, read-only, default closed.
- Stack: Flutter web, own schema, no `sodalite_platform` dependency.
- v1 catalog: full layer info including inspectionView and actions.

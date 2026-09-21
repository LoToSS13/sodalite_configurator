# Sodalite Configurator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Flutter web app that authors a valid `configurable_module` Consul pack (`apps/{slug}/*.json`) as nested blocks, with export disabled until the document has zero validation errors.

**Architecture:** A Dart schema catalog describes node types, fields, and slots. A `Node` tree is the document. `validate` walks the tree. Codecs map subtrees to Consul JSON. The UI only renders schema slots and never lets the user invent keys. No dependency on `sodalite_platform`.

**Tech Stack:** Flutter 3.35 / Dart 3.9, web only (HTML renderer), `archive`, `file_picker`, `web` (download + `localStorage`). State: `ChangeNotifier` + immutable `Node` updates. Tests: `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-21-sodalite-configurator-design.md`

## Global Constraints

- Flutter SDK `3.35.7` / Dart `>=3.8.0 <4.0.0`; Dart line length 120
- Web only; HTML renderer; no canvaskit requirement
- No Consul, no Jasper, no `sodalite_platform` dependency
- UI copy in Russian; JSON keys English as in Consul
- Export filename `{slug}-sodalite-module.zip`; JSON 2-space indent, UTF-8, schema field order
- `slug` pattern `^[a-z0-9][a-z0-9_-]*$`; not a JSON key
- Zip always contains `app.json`, `base_layer.json`, `additional_layers.json`; `object_creation.json` / `search.json` only when those features are on
- Configurator is stricter than app parsers: silently-dropped optional items are blocking errors
- Read-only JSON preview; no TextField in the preview widget
- Frequent commits after each task; do not skip hooks

## File map

| Path | Responsibility |
|---|---|
| `lib/schema/issue.dart` | `Issue` |
| `lib/schema/field_spec.dart` | `FieldKind`, `FieldSpec` |
| `lib/schema/slot_spec.dart` | `SlotCardinality`, `SlotSpec` |
| `lib/schema/node_type.dart` | `NodeType` |
| `lib/schema/node.dart` | `Node` tree + `newNodeId` + `copyWith` |
| `lib/schema/catalog.dart` | All `NodeType`s for the module pack |
| `lib/schema/validator.dart` | `validate(Node, Catalog) → List<Issue>` |
| `lib/schema/placeholders.dart` | `{Ident}` extraction and membership checks |
| `lib/codec/json_format.dart` | `encodeJson(Map)` 2-space stable keys |
| `lib/codec/app_codec.dart` | App ↔ `app.json` |
| `lib/codec/layer_codec.dart` | Layer ↔ `base_layer.json` / array item |
| `lib/codec/object_creation_codec.dart` | ObjectCreation ↔ `object_creation.json` |
| `lib/codec/search_codec.dart` | Search ↔ `search.json` |
| `lib/codec/module_codec.dart` | `ModuleFiles` encode/decode + import warnings |
| `lib/codec/zip_io.dart` | Build/parse `apps/{slug}/` zip bytes |
| `lib/document/document_controller.dart` | Selection, mutations, completeness, feature toggles |
| `lib/persistence/draft_store.dart` | `localStorage` drafts |
| `lib/ui/strings.dart` | Russian labels |
| `lib/ui/home/home_page.dart` | New / open / drafts |
| `lib/ui/editor/editor_page.dart` | Canvas + top bar |
| `lib/ui/editor/block_card.dart` | Recursive block |
| `lib/ui/editor/slot_add_button.dart` | «+» menu filtered by `SlotSpec.allowedTypeIds` |
| `lib/ui/editor/completeness_panel.dart` | Issue list |
| `lib/ui/editor/json_preview.dart` | Read-only preview |
| `lib/ui/editor/field_controls.dart` | Field widgets by `FieldKind` |
| `test/schema/…`, `test/codec/…`, `test/document/…`, `test/ui/…` | Tests next to the layer they cover |

---

### Task 1: Flutter web skeleton

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `web/index.html` (via `flutter create`)
- Modify: `.gitignore` (keep `.superpowers/` ignored)
- Test: `test/widget_test.dart` replaced in later tasks

**Interfaces:**
- Consumes: empty directory with docs already present
- Produces: runnable `sodalite_configurator` web app; package name `sodalite_configurator`

- [ ] **Step 1: Create the Flutter web project in the existing folder**

Run from `/Users/alekseizubankov/Development/Gems/sodalite-configurator`:

```bash
flutter create --platforms=web --org=ru.gems --project-name=sodalite_configurator .
```

Expected: `pubspec.yaml` exists; `lib/main.dart` exists.

- [ ] **Step 2: Pin SDK and deps**

Set `pubspec.yaml` environment to `sdk: '>=3.8.0 <4.0.0'`. Add dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  archive: ^4.0.0
  file_picker: ^8.1.0
  web: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

Create `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    always_use_package_imports: true
formatter:
  page_width: 120
```

In `web/index.html` keep default. In `web/flutter_bootstrap.js` or the loader, we will pass HTML renderer in Task 8; for now run tests with default.

- [ ] **Step 3: Init git if needed and commit**

```bash
git init
git add pubspec.yaml analysis_options.yaml lib web test .gitignore
git commit -m "$(cat <<'EOF'
chore: scaffold Flutter web app for the configurator

EOF
)"
```

Do not add `.superpowers/` (already gitignored).

---

### Task 2: Schema kernel — Node, specs, validate required fields

**Files:**
- Create: `lib/schema/issue.dart`, `lib/schema/field_spec.dart`, `lib/schema/slot_spec.dart`, `lib/schema/node_type.dart`, `lib/schema/node.dart`, `lib/schema/catalog.dart`, `lib/schema/validator.dart`
- Test: `test/schema/validator_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:

```dart
enum FieldKind { string, nonEmptyString, boolean, integer, enumeration, color, stringMap, stringList }

@immutable
class FieldSpec {
  final String key;
  final FieldKind kind;
  final bool required;
  final List<String>? enumValues;
  final int? min;
  final int? max;
  final String? pattern;
  final Object? defaultValue;
  const FieldSpec({required this.key, required this.kind, this.required = false, this.enumValues, this.min, this.max, this.pattern, this.defaultValue});
}

enum SlotCardinality { one, optionalOne, list }

@immutable
class SlotSpec {
  final String key;
  final SlotCardinality cardinality;
  final List<String> allowedTypeIds;
  final bool required;
  const SlotSpec({required this.key, required this.cardinality, required this.allowedTypeIds, this.required = false});
}

@immutable
class NodeType {
  final String id;
  final String labelRu;
  final List<FieldSpec> fields;
  final List<SlotSpec> slots;
  const NodeType({required this.id, required this.labelRu, this.fields = const [], this.slots = const []});
}

@immutable
class Node {
  final String id;
  final String typeId;
  final Map<String, Object?> fields;
  final Map<String, List<Node>> childrenBySlot;
  const Node({required this.id, required this.typeId, this.fields = const {}, this.childrenBySlot = const {}});
  Node copyWith({Map<String, Object?>? fields, Map<String, List<Node>>? childrenBySlot});
  Node? find(String nodeId);
}

String newNodeId(); // uuid-like, e.g. timestamp+counter is fine in tests if injected

@immutable
class Issue {
  final String nodeId;
  final String path;
  final String message;
  const Issue({required this.nodeId, required this.path, required this.message});
}

class Catalog {
  final Map<String, NodeType> types;
  const Catalog(this.types);
  NodeType type(String id);
  static Catalog empty(); // test helper
}

List<Issue> validate(Node root, Catalog catalog);
```

`validate` in this task only: unknown `typeId` → issue; missing required slot `one`/`required list min 1`; required `nonEmptyString` blank; `integer` outside min/max; `enumeration` not in `enumValues`; `color` not matching `^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$`; `pattern` mismatch.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sodalite_configurator/schema/catalog.dart';
import 'package:sodalite_configurator/schema/field_spec.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/schema/node_type.dart';
import 'package:sodalite_configurator/schema/slot_spec.dart';
import 'package:sodalite_configurator/schema/validator.dart';

void main() {
  final catalog = Catalog({
    'app': NodeType(
      id: 'app',
      labelRu: 'Карточка модуля',
      fields: const [
        FieldSpec(key: 'title', kind: FieldKind.nonEmptyString, required: true),
        FieldSpec(key: 'subtitle', kind: FieldKind.nonEmptyString, required: true),
      ],
    ),
  });

  test('blank required title is an issue', () {
    const node = Node(id: 'n1', typeId: 'app', fields: {'title': '', 'subtitle': 'x'});
    final issues = validate(node, catalog);
    expect(issues.single.path, 'title');
    expect(issues.single.nodeId, 'n1');
  });

  test('filled required fields produce no issues', () {
    const node = Node(id: 'n1', typeId: 'app', fields: {'title': 'A', 'subtitle': 'B'});
    expect(validate(node, catalog), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/schema/validator_test.dart --no-pub`  
Expected: FAIL compiling (`validator.dart` missing) or "validate not defined".

- [ ] **Step 3: Write minimal implementation**

Implement the files listed above. `Catalog.type` throws `StateError` on unknown id. `validate` looks up `NodeType`, walks fields then slots recursively. For `SlotCardinality.one`, exactly one child; missing → issue on that slot path. For `optionalOne`, 0 or 1. For `list` with `required: true`, length ≥ 1.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/schema/validator_test.dart --no-pub`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/schema test/schema
git commit -m "$(cat <<'EOF'
feat: add schema kernel and required-field validation

EOF
)"
```

---

### Task 3: ModuleBundle catalog — App, Geo, Layer, feature slots

**Files:**
- Modify: `lib/schema/catalog.dart` — add `Catalog.modulePack()`
- Create: `lib/schema/ids.dart` — const type ids
- Test: `test/schema/module_bundle_validate_test.dart`

**Interfaces:**
- Consumes: `validate`, `Catalog`, `Node`
- Produces: `Catalog.modulePack()` with type ids:

```dart
abstract final class TypeIds {
  static const moduleBundle = 'moduleBundle';
  static const app = 'app';
  static const layer = 'layer';
  static const geo = 'geo';
  static const geoSource = 'geoSource';
  static const geoRule = 'geoRule';
  static const geoStyle = 'geoStyle';
}
```

`moduleBundle` fields: `slug` (`nonEmptyString`, required, pattern `^[a-z0-9][a-z0-9_-]*$`).  
Slots: `app` one required `app`; `baseLayer` one required `layer`; `additionalLayers` list of `layer`; `objectCreation` optionalOne (type registered empty in this task as placeholder node type `objectCreation` with field `xsdPath` required — full codec later); `search` optionalOne similarly.

`geo` fields: `alias` required nonEmptyString; `name` string; `visibilityThreshold` integer min 15 max 17; `hasMarkers` boolean required default true; `showTagInCluster` boolean required default true. Slots: `style` optionalOne `geoStyle`; `sources` list of `geoSource`.

`geoStyle` fields: `color` required color; `isDashed` required boolean.

`geoSource` fields: `name` string; `icon` string; `view` string. Slots: `style` optionalOne `geoStyle`; `rule` optionalOne `geoRule`. Custom constraint in validator: at least one of non-empty `view` or a `rule` child.

`geoRule` fields: `operator` enumeration `eq|noteq|isnotnull|isnull|notin` required; `property` required nonEmptyString; `value` string. Custom constraint: `value` non-empty when operator is `eq`, `noteq`, `notin`.

`layer` slots: `geo` one required; `info` optionalOne — register `info` type with only `alias` required in this task so the slot exists; fill Info in Task 8.

Helper:

```dart
Node newModuleBundle({required String slug, required String Function() id})
```

creates app + baseLayer.geo with defaults `hasMarkers: true`, `showTagInCluster: true`. Additional layers created later set both defaults to `false`.

- [ ] **Step 1: Write the failing test**

```dart
test('new module without geo.alias cannot export', () {
  final catalog = Catalog.modulePack();
  final doc = newModuleBundle(slug: 'land_v2', id: () => 'id-${_n++}');
  final issues = validate(doc, catalog);
  expect(issues.any((i) => i.path.endsWith('alias')), isTrue);
});

test('geo source without view and rule is an issue', () {
  // build a geoSource with empty view and no rule child
});

test('slug Land_Control is invalid', () {
  final node = Node(id: 'm', typeId: TypeIds.moduleBundle, fields: {'slug': 'Land_Control'});
  expect(validate(node, Catalog.modulePack()).any((i) => i.path == 'slug'), isTrue);
});
```

- [ ] **Step 2: Run test — expect FAIL** (`Catalog.modulePack` missing)

- [ ] **Step 3: Implement catalog + extra checks in `validate` for geoSource view/rule and geoRule value**

Put type-specific constraints in `lib/schema/constraints.dart`:

```dart
List<Issue> extraConstraints(Node node, Catalog catalog);
```

called from `validate` after generic field/slot checks.

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit** `feat: register module bundle, layer geo, and slug rules`

---

### Task 4: App + Layer Geo codecs

**Files:**
- Create: `lib/codec/json_format.dart`, `lib/codec/app_codec.dart`, `lib/codec/layer_codec.dart`, `lib/codec/module_codec.dart`
- Test: `test/codec/app_codec_test.dart`, `test/codec/layer_codec_test.dart`, `test/codec/module_codec_test.dart`

**Interfaces:**
- Consumes: `Node`, `Catalog.modulePack()`
- Produces:

```dart
String encodeJson(Object value); // JsonEncoder.withIndent('  ')

Map<String, dynamic> encodeApp(Node app);
Node decodeApp(Map<String, dynamic> json, {required String id});

Map<String, dynamic> encodeLayer(Node layer);
({Node layer, List<ImportWarning> warnings}) decodeLayer(Object json, {required String id, required bool isBase});

@immutable
class ImportWarning {
  final String file;
  final String message;
  const ImportWarning({required this.file, required this.message});
}

@immutable
class ModuleFiles {
  final String slug;
  final Map<String, dynamic> app;
  final Map<String, dynamic> baseLayer;
  final List<Map<String, dynamic>> additionalLayers;
  final Map<String, dynamic>? objectCreation;
  final Map<String, dynamic>? search;
}

ModuleFiles encodeModule(Node bundle);
({Node bundle, List<ImportWarning> warnings}) decodeModule(ModuleFiles files, {required String Function() id});
```

`encodeLayer` writes `geo` then optional `info`. `geo.hasMarkers` and `geo.showTagInCluster` always written. `visibilityThreshold` omitted if field is null. `style` omitted if no child. `sources` omitted if empty. `rule.value` written as `""` for null-check operators.

`decodeLayer`: if root is `List`, caller uses `decodeAdditional`. If extra keys exist, add `ImportWarning` and drop them. `isBase` selects default bools only when keys are missing on import (imported files may omit them; after decode the Node always has explicit bools).

Key order for `geo`: `alias`, `name`, `visibilityThreshold`, `hasMarkers`, `showTagInCluster`, `style`, `sources`.

- [ ] **Step 1: Failing tests**

`app_codec_test.dart`: encode `title`/`subtitle`; decode rejects missing title by still building a node with empty title (validation, not throw). Extra key `foo` → warning.

`layer_codec_test.dart`: round-trip a geo with alias, dashed style, one source with `view`, one source with `rule` `eq`. `additional_layers` object (not array) normalizes to one layer.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement codecs. Do not throw on missing required JSON keys; fill empty strings so the editor can show errors.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: encode and decode app.json and layer geo`

---

### Task 5: Zip export of a complete geo-only module

**Files:**
- Create: `lib/codec/zip_io.dart`
- Test: `test/codec/zip_io_test.dart`

**Interfaces:**
- Consumes: `encodeModule`
- Produces:

```dart
List<int> buildModuleZip(ModuleFiles files);
({ModuleFiles files, List<ImportWarning> warnings}) parseModuleZip(List<int> bytes);
```

Zip entries:

```
apps/{slug}/app.json
apps/{slug}/base_layer.json
apps/{slug}/additional_layers.json
```

plus optional creation/search. `additional_layers.json` is a JSON array (pretty-printed). Filename for download is not this task.

If `objectCreation` / `search` on `ModuleFiles` are null, omit those entries.

- [ ] **Step 1: Test**

```dart
test('zip contains three json files under apps/slug', () {
  final bytes = buildModuleZip(ModuleFiles(
    slug: 'land_v2',
    app: {'title': 'T', 'subtitle': 'S'},
    baseLayer: {'geo': {'alias': 'L', 'hasMarkers': true, 'showTagInCluster': true}},
    additionalLayers: const [],
  ));
  final archive = ZipDecoder().decodeBytes(bytes);
  final names = archive.files.map((f) => f.name).toSet();
  expect(names, {
    'apps/land_v2/app.json',
    'apps/land_v2/base_layer.json',
    'apps/land_v2/additional_layers.json',
  });
});
```

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement with `package:archive` `ZipEncoder` / `ZipDecoder`. UTF-8. `additional_layers.json` body `[]` when empty.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: pack module JSON into apps/slug zip`

---

### Task 6: DocumentController

**Files:**
- Create: `lib/document/document_controller.dart`
- Test: `test/document/document_controller_test.dart`

**Interfaces:**
- Consumes: `Node`, `validate`, `Catalog.modulePack`, `encodeModule`, `buildModuleZip`
- Produces:

```dart
class DocumentController extends ChangeNotifier {
  DocumentController({required this.catalog, required Node root});
  final Catalog catalog;
  Node get root;
  String? get selectedId;
  List<Issue> get issues;
  bool get canExport;
  void select(String? id);
  void setField(String nodeId, String key, Object? value);
  void addChild({required String parentId, required String slot, required String typeId});
  void removeNode(String nodeId);
  void enableObjectCreation();
  void disableObjectCreation();
  void enableSearch();
  void disableSearch();
  List<int> exportZip(); // throws StateError if !canExport
}
```

`addChild` must reject `typeId` not in `SlotSpec.allowedTypeIds` (`ArgumentError`). `list` appends; `one`/`optionalOne` replaces if present only after remove, or no-ops if already filled for `one`. Feature enable inserts a child in the optional slot; disable removes it.

Defaults when adding additional `layer`: `hasMarkers: false`, `showTagInCluster: false`.

- [ ] **Step 1: Tests** — `canExport` false until title, subtitle, geo.alias set; `addChild` cannot put `app` into `sources`; `exportZip` throws when incomplete; after filling required fields `exportZip` returns bytes parseable by `parseModuleZip`.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement. Mutations copy the path from root to the target node (immutable). `issues` recomputed after each mutation.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: document controller mutations and export gate`

---

### Task 7: Editor UI — document of blocks, completeness, zip download

**Files:**
- Create: `lib/ui/strings.dart`, `lib/ui/home/home_page.dart`, `lib/ui/editor/editor_page.dart`, `lib/ui/editor/block_card.dart`, `lib/ui/editor/slot_add_button.dart`, `lib/ui/editor/completeness_panel.dart`, `lib/ui/editor/field_controls.dart`, `lib/ui/app.dart`
- Modify: `lib/main.dart`
- Test: `test/ui/editor_page_test.dart`, `test/ui/slot_add_button_test.dart`

**Interfaces:**
- Consumes: `DocumentController`
- Produces: material app; home «Создать модуль» asks slug then pushes editor; editor top bar shows issue count and «Скачать zip» (`Key('exportZip')`) disabled when `!canExport`; right panel lists issues; canvas shows App card and Base layer card; slot buttons labeled from `NodeType.labelRu`.

Download helper `lib/codec/download.dart`:

```dart
void downloadBytes({required String filename, required List<int> bytes})
```

uses `package:web` `AnchorElement` + `Url.createObjectUrlFromBlob`. In widget tests, inject `DownloadFn` so tests do not touch the browser.

- [ ] **Step 1: Widget tests**

```dart
testWidgets('export button disabled until complete', (tester) async {
  await tester.pumpWidget(ConfiguratorApp(controller: incompleteController));
  final button = tester.widget<Button>(find.byKey(const Key('exportZip')));
  // use FilledButton
  expect(tester.widget<FilledButton>(find.byKey(const Key('exportZip'))).onPressed, isNull);
});

testWidgets('sources slot add menu does not offer app', (tester) async {
  // open the + on geo.sources; expect items geoSource only
});
```

Russian strings in `lib/ui/strings.dart`: `createModule`, `openZip`, `downloadZip`, `issuesCount(int n)`, `enableObjectCreation`, `enableSearch`, `addAdditionalLayer`, `jsonPreview`.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement recursive `BlockCard`: title = `type.labelRu`; fields via `FieldControls`; each slot shows children then `SlotAddButton` if cardinality allows another child. Click issue → `controller.select` and `Scrollable.ensureVisible` via keys `Key('node-${id}')`.**

On the canvas, after additional-layers slot, show two dashed buttons calling `enableObjectCreation` / `enableSearch` (hide once the slot is filled; the block card then has a remove/disable action).

On the canvas, after additional-layers slot, show two dashed buttons calling `enableObjectCreation` / `enableSearch` (hide once the slot is filled; the block card then has a remove/disable action).

`main.dart`: `runApp(const ConfiguratorApp());`. `ConfiguratorApp` holds optional injected controller for tests; otherwise home page.

Pass `--web-renderer html` in README run command. Add `README.md` with:

```bash
flutter run -d chrome --web-renderer html
```

- [ ] **Step 4: PASS `flutter test test/ui --no-pub`**

- [ ] **Step 5: Commit** `feat: editor canvas with slot add and gated zip download`

---

### Task 8: Info — paths, titles, sections, media, placeholders

**Files:**
- Modify: `lib/schema/ids.dart`, `lib/schema/catalog.dart`, `lib/schema/constraints.dart`, `lib/codec/layer_codec.dart`
- Create: `lib/schema/placeholders.dart`
- Test: `test/schema/placeholders_test.dart`, `test/codec/info_codec_test.dart`

**Interfaces:**
- Consumes: Layer codec
- Produces: type ids `info`, `infoSection`, `fieldRow`, `imageSection`, `attachmentSection`

`info` fields: `alias` required; `paths` stringMap; `titleContent`, `subtitleContent`, `statusContent` strings (JSON `{content}`); `additionalTitle` string.  
Slots: `infoSections` list `infoSection`; `images` list `imageSection`; `attachments` list `attachmentSection`; `inspectionView` list (empty type until Task 9); `actions` list (until Task 9).

`infoSection`: `title` string; slot `fields` list required of `fieldRow`.  
`fieldRow`: `name` required, `content` required, `separator`, `url`, `ifTrue`, `ifFalse` strings.

`imageSection` / `attachmentSection`: `title` string; `sources` stringList required non-empty. Attachments extra `extensions` stringList optional.

`extractPlaceholders(String s)` → identifiers inside `{…}` matching `[A-Za-z_][A-Za-z0-9_]*`.

Constraints: every placeholder in info title/subtitle/status/fieldRow content+url ⊆ `paths` keys. Each image source key must exist in `paths` and start with `Image_`. Attachment sources start with `Attachments_`. Invalid extension token (empty after trim/lower) → issue.

JSON: export `title: {content}` only if `titleContent` non-empty. `paths` omitted if empty. `fields` at info root never exported. Import: if `info.fields` array present, convert to one `infoSection` with empty title; warning `legacy fields converted`. Drop `preview` and `acceptance` with warning.

- [ ] **Step 1: Tests for placeholder extraction; unmatched `{Foo}`; round-trip infoSections; import legacy fields.**

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement encode/decode of `info` inside `encodeLayer` / `decodeLayer`. Key order: `alias`, `paths`, `title`, `subtitle`, `status`, `additionalTitle`, `infoSections`, `images`, `attachments`, `inspectionView`, `actions`.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: layer info sections, media, and placeholder checks`

---

### Task 9: inspectionView + actions

**Files:**
- Modify: catalog, constraints, `layer_codec.dart`
- Test: `test/codec/inspection_actions_codec_test.dart`

**Interfaces:**
- Type ids: `inspectionTab`, `inspectionObject`, `inspectionCreation`, `actionInformationChange`, `actionGeometryChange`

`inspectionTab` fields: `tabName`, `processName`. Slots: `objects` list of `inspectionObject` (JSON object map keyed by `pathKey` field); `creation` optionalOne `inspectionCreation`. At least one object required.

`inspectionObject` fields: `pathKey` required (must be a key of parent Info.paths); `endpoints` stringMap required non-empty; `titleContent` required; `subtitleContent`; `tagColor`, `tagContent`, `tagIfTrue`; `imagesSource`; `attachmentsSource`; `extensions` stringList. Slot `fields` list of `fieldRow`. Placeholders in title/subtitle/tag/fields ⊆ this object’s `endpoints` keys.

`inspectionCreation`: `title`, `xsdPath`, `relateToObjectKey` required; `condition` string; `requireDateWatermark` bool default true; `saveToGallery` bool default false.

Actions slot on info allows `actionInformationChange` (`xsdPath` required) and `actionGeometryChange` (`xsdPath` required; `geometryTypes` stringList of `point|line|polygon` required non-empty). JSON `type` is `informationChange` / `geometryChange`. Unknown type on import → warning, skip that action (and add an issue if you instead insert an error node — prefer skip + warning so the rest of the file loads, plus a completeness issue «action dropped» only as warning; remaining document may still be valid). Spec: unknown type fails import as an error node. Implement: insert a node `actionUnknown` with field `rawType` that always validates as error so export stays blocked until the user deletes it.

- [ ] **Step 1: Tests** — encode inspection tab with one object; placeholders `{Name}` valid when endpoints has `Name`; geometryChange without types is invalid; round-trip actions.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement JSON `inspectionView` as array of maps with `objects` as map. `creation` nested object.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: inspectionView and layer actions blocks`

---

### Task 10: ObjectCreation feature

**Files:**
- Modify: catalog (replace stub), `lib/codec/object_creation_codec.dart`, `module_codec.dart`
- Test: `test/codec/object_creation_codec_test.dart`

**Interfaces:**

`objectCreation` fields: `xsdPath` required; `requireDateWatermark` bool default true; `saveToGallery` bool default false; `color` optional color; `iconPath` optional string. Slot `geometryTypes` list of `geometryType` nodes (`type` enum point|line|polygon required; `autoMode` bool allowed only when type is `point` — extra constraint).

JSON:

```json
{
  "xsdPath": "…",
  "geometryTypes": [{"type": "point", "autoMode": true}],
  "requireDateWatermark": true,
  "saveToGallery": false,
  "style": {"color": "#112233", "iconPath": "apps/x/a.svg"}
}
```

Omit `style` if both color and iconPath empty. Omit `geometryTypes` if slot empty. `encodeModule` includes the file iff the slot has a child.

- [ ] **Step 1: Tests** — feature off → zip has no object_creation.json; feature on without xsdPath → `canExport` false; autoMode on line → issue.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement codec + controller already has enable/disable from Task 6.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: object creation feature file and geometry types`

---

### Task 11: Search feature and filter tree

**Files:**
- Modify: catalog, `lib/codec/search_codec.dart`, `module_codec.dart`, constraints
- Test: `test/codec/search_codec_test.dart`, `test/schema/search_filter_validate_test.dart`

**Interfaces:**

Types: `search`, `searchObject`, `searchFilterGroup`, `searchFilterScalar`, `searchFilterList`, `searchFilterEmpty`.

`search` fields: `placeholder` string. Slot `searchObjects` list required of `searchObject`.

`searchObject` fields: `alias`, `objectKeyFieldPath`, `attribute` required; `paths` stringMap required non-empty; `title` required (resultView.title); `subtitle1`, `subtitle2` optional; `aopJetAlias`, `aopKeyField` optional pair (both or neither). Slot `filter` optionalOne `searchFilterGroup` only (root cannot be a leaf). `attribute` must not contain `/`.

Filter group: `operator` enum `and|or`; slot `criterions` list required (≥1) allowing group + three leaf types.

Scalar leaf: operator `eq|noteq|like|notlike|gt|lt|gte|lte`; `alias` required; `value` required string.  
List leaf: operator `in|notin`; `alias`; `value` stringList non-empty.  
Empty leaf: operator `empty|notempty`; `alias`; no value.

Consul JSON leaf (export and import):

```json
{ "operator": "eq", "alias": "Status", "value": "active" }
```

Group:

```json
{ "operator": "and", "criterions": [ … ] }
```

Do not export Jasper `{property: {alias, type: field}}`. On import, if a leaf has `property` instead of `alias`, treat as invalid leaf (warning + error node) — matches platform tests.

`alternativePositionObject` JSON only when both AOP fields set.

- [ ] **Step 1: Tests** — search with zero objects invalid; attribute `a/b` invalid; round-trip and/or + eq + in; zip omits search.json when feature off; filter root leaf rejected.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: search.json objects and Consul-shaped filter tree`

---

### Task 12: Import zip/files

**Files:**
- Modify: `lib/codec/zip_io.dart`, `lib/ui/home/home_page.dart`, `lib/document/document_controller.dart`
- Create: `lib/codec/import_files.dart`
- Test: `test/codec/zip_import_test.dart`, `test/ui/import_errors_test.dart`

**Interfaces:**

```dart
@immutable
class ImportResult {
  final Node? bundle;
  final List<ImportWarning> warnings;
  final List<String> errors; // per-file failures; bundle still built from the files that parsed
}

ImportResult importZip(List<int> bytes, {required String Function() id});
ImportResult importLooseFiles(Map<String, String> nameToContent, {String? slug, required String Function() id});
```

Zip: find `apps/{slug}/` prefix; if multiple slugs, error and `bundle == null`. Unknown extra files → warning. Missing `app.json` → still build module with empty app (completeness fails). JSON syntax error in one file → `errors` entry `app.json: FormatException…`, that file skipped.

Loose files: keys may be `app.json` etc. If `slug` null, use `imported` and let the user edit slug.

Home page: «Открыть zip» uses `file_picker`. Failed import: `AlertDialog` with the error strings; stay on home if `bundle == null`, else open editor with warnings banner.

- [ ] **Step 1: Tests** — round-trip zip from Task 5; broken JSON in search.json does not drop base_layer; extra `readme.txt` warns; `additional_layers` as object becomes one layer.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement parse using `parseModuleZip` + `decodeModule`**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: import module zip and partial JSON with warnings`

---

### Task 13: Drafts + JSON preview

**Files:**
- Create: `lib/persistence/draft_store.dart`, `lib/ui/editor/json_preview.dart`
- Modify: `editor_page.dart`, `home_page.dart`
- Test: `test/persistence/draft_store_test.dart`, `test/ui/json_preview_test.dart`

**Interfaces:**

```dart
abstract class DraftStore {
  Future<void> save(Node root);
  Future<Node?> load(String slug);
  Future<List<DraftMeta>> list();
  Future<void> delete(String slug);
}

@immutable
class DraftMeta {
  final String slug;
  final String title;
  final DateTime updatedAt;
}
```

Web implementation: `window.localStorage` key `sodalite-configurator.draft.{slug}` value JSON of `{updatedAt, tree: <node json>}`. Tree serialization is an internal format (`typeId`, `id`, `fields`, `childrenBySlot`), not Consul JSON. Corrupt JSON → `load` returns null (home ignores that entry).

`DocumentController` calls `save` after mutations (debounce 300ms).

JSON preview: `JsonPreview(text: encodeJson(previewMap))` where `previewMap` is `encodeModule` output even if incomplete (empty strings allowed). Widget is `SelectableText` or `Text`; **no `TextField`**. Toggle in top bar; default closed. When open, replaces the completeness list (issue count remains in the top bar).

- [ ] **Step 1: Tests** — save/load round-trip with a fake `Map<String,String>` store; corrupt load null; `find.byType(TextField)` in preview subtree is empty; export still disabled while preview open if issues exist.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement. Inject `DraftStore` in tests.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: localStorage drafts and read-only JSON preview`

---

### Task 14: Full golden round-trip and README

**Files:**
- Create: `test/codec/goldens/full_module.json` (a map of filenames → objects, loaded in test)
- Create: `test/codec/full_module_round_trip_test.dart`
- Modify: `README.md`

**Interfaces:** Consumes every codec. Produces a fixture that includes: app, base layer with geo sources + info sections + media + inspectionView + both actions, one additional layer, object_creation, search with filter group.

- [ ] **Step 1: Write golden maps in Dart (not Consul-incompatible keys). Test: `decodeModule(encodeModule(decodeModule(golden)))` equals structurally (compare `encodeModule` maps).**

Also `validate` on that tree is empty and `buildModuleZip` contains five JSON files.

- [ ] **Step 2: FAIL until fixture is complete**

- [ ] **Step 3: Fill any missing encode branches discovered by the golden. README usage: create module, fill required, download zip, copy into Consul `apps/{slug}/`.**

- [ ] **Step 4: `flutter test --no-pub` all green; `dart analyze` no issues**

- [ ] **Step 5: Commit** `test: golden round-trip of a full configurable module`

---

## Spec coverage

| Spec section | Task |
|---|---|
| Schema-driven slots, no user JSON keys | 2–3, 7 |
| Module zip layout / optional creation+search files | 5, 10, 11 |
| App title/subtitle / slug | 3–4 |
| Geo + sources at-least-one view/rule | 3–4 |
| Info sections, media, placeholders, legacy fields import | 8, 12 |
| inspectionView + actions | 9 |
| ObjectCreation | 10 |
| Search + Consul filter shape | 11 |
| Stricter than parsers | 2–11 extraConstraints |
| Import zip / loose / errors | 12 |
| Completeness-gated export, Russian UI, document layout | 7 |
| Read-only JSON preview | 13 |
| localStorage drafts | 13 |
| No platform / Consul / Jasper | all |
| Widget tests for slot menu and disabled export | 7 |
| HTML renderer | 7 README |

## Placeholder / consistency notes

Type ids and method names above are the names later tasks must use (`encodeModule`, `DocumentController.canExport`, `TypeIds.geoSource`, `DraftStore.load`). Do not rename without updating every task.

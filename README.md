# Sodalite Configurator

Offline Flutter web editor for Sodalite configurable module packs. The form is in Russian; exported JSON keys match Consul. The app does not talk to Consul, Jasper, or `sodalite_platform`.

## Run

```bash
flutter run -d chrome
```

HTML renderer was the original intent, but Flutter 3.38+ dropped the `--web-renderer` flag.

## Usage

1. Create a module and set a `slug` (`a-z`, `0-9`, `_`, `-`).
2. Fill required blocks until the remarks count is zero. Optional **создание объектов** and **поиск** add `object_creation.json` / `search.json` only when enabled.
3. Download `{slug}-sodalite-module.zip`. Export stays disabled while the document has issues.
4. Unpack the zip into Consul as `apps/{slug}/` (`app.json`, `base_layer.json`, `additional_layers.json`, and the optional feature files).

Home also opens an existing zip (or a set of those JSON files). Incomplete imports stay editable; export remains blocked until the tree is valid. Drafts autosave in the browser `localStorage` and do not clear on download. The JSON panel is a read-only preview of the current tree, not a second editor.

## Test

```bash
flutter test --no-pub
```

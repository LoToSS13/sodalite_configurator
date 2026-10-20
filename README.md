# Sodalite Configurator

Offline Flutter web editor for Sodalite configurable module packs. The form is in Russian; exported JSON keys match Consul. ZIP download works without a network. Optional Consul and Jasper connections stay in this browser and are not written into the module.

## Run

```bash
flutter run -d chrome
```

HTML renderer was the original intent, but Flutter 3.38+ dropped the `--web-renderer` flag.

## Usage

1. Create a module and set a `slug` (`a-z`, `0-9`, `_`, `-`).
2. Fill required blocks until the remarks count is zero. Optional **создание объектов** and **поиск** add `object_creation.json` / `search.json` only when enabled.
3. Download `{slug}-sodalite-module.zip`. An unfinished module warns before the file is saved.
4. Unpack the zip into Consul as `apps/{slug}/` (`app.json`, `base_layer.json`, `additional_layers.json`, and the optional feature files).

## Integrations

The home page block «Интеграции» stores a Consul address and API key, and the Jasper connection. Jasper login uses the Identity authorization-code flow in the browser. The access token is refreshed from a button in that block. The XSD list loads after login, when the editor opens, and from «Обновить список XSD». A ready module can be written to Consul at `apps/{slug}/` in one transaction. An unfinished module is not uploaded. The browser can call these servers only if they allow this site (CORS).

Home also opens an existing zip (or a set of those JSON files). Incomplete imports stay editable. A ZIP of an unfinished module asks for confirmation; Consul upload stays blocked until the tree is valid. Drafts autosave in the browser `localStorage` and do not clear on download. The JSON panel is a read-only preview of the current tree, not a second editor.

## Test

```bash
flutter test --no-pub
```

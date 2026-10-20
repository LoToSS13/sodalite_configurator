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

The home page block «Интеграции» stores a list of named contours. Each contour keeps its own Consul URL and Token, and the Jasper Base URL, Auth URL, Client ID, Client Secret and Scope. Jasper field names match the Postman OAuth 2.0 dialog. Auth URL may be the full Postman value; the Access Token URL on the same server is derived from it. Callback URL can be copied for the Identity client. Jasper login uses the authorization-code flow in the browser. The access token is refreshed from a button in that block. The XSD list loads after login, when the editor opens, and from «Обновить список XSD». An empty list is followed by `GET /api/v1/rights`: the notice says the client has no creation schemas and reports the viewing rights from that response. A path typed into an XSD field stays valid when it is absent from that list; the field only shows a remark. A ready module can be written to Consul at `apps/{slug}/` in one transaction. The confirmation first reads the folder and shows the current title and files. «Из Consul» on the home page reads that folder back into a draft and uses the same replace-or-copy prompt as a ZIP. A draft card can be duplicated without changing the original. An unfinished module is not uploaded. The browser can call these servers only if they allow this site (CORS).

Home also opens an existing zip (or a set of those JSON files). Incomplete imports stay editable. A ZIP of an unfinished module asks for confirmation; Consul upload stays blocked until the tree is valid. Drafts autosave in the browser `localStorage` and do not clear on download. The JSON panel is a read-only preview of the current tree, not a second editor.

## Test

```bash
flutter test --no-pub
```

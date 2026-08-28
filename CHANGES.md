# 0.1.0 (2026-08-28)

- Initial release.
- Lwt-based client with `X-API-Key` header or `api_key` query authentication
  and key resolution from `FXMACRODATA_API_KEY` / `FXMD_API_KEY`.
- Typed endpoint functions: `ping`, `data_catalogue`, `release_calendar`,
  `macro_indicator`, `forex`, `cot`, `commodity`.
- Generic `get_json` / `get_data` access to any endpoint of the public API.

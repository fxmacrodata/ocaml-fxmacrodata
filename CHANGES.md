# 0.1.1 (unreleased)

- Documentation fix: the README, the `latest_announcements` example and the
  `macro_indicator` doc comment all used the indicator slug `inflation_rate`,
  which the API answers with 404. The slug is `inflation`. Copy-pasting the
  README example previously failed.

# 0.1.0 (2026-08-28)

- Initial release.
- Lwt-based client with `X-API-Key` header or `api_key` query authentication
  and key resolution from `FXMACRODATA_API_KEY` / `FXMD_API_KEY`.
- Typed endpoint functions: `ping`, `data_catalogue`, `release_calendar`,
  `macro_indicator`, `forex`, `cot`, `commodity`.
- Generic `get_json` / `get_data` access to any endpoint of the public API.

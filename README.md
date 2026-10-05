# ocaml-fxmacrodata

OCaml client for the [FXMacroData](https://fxmacrodata.com/?utm_source=github&utm_medium=referral&utm_campaign=ocaml-fxmacrodata&utm_content=readme) API — official-source
forex and macroeconomic data: central-bank announcements, macroeconomic
indicator time series, economic release calendars, CFTC Commitment of Traders
positioning, commodities, and FX spot-rate history across 18 catalogue
currencies (AUD, BRL, CAD, CHF, CNH, CNY, DKK, EUR, GBP, ILS, JPY, NGN, NOK,
NZD, PEN, SEK, THB, USD).

## Install

```sh
opam install fxmacrodata
```

## Quickstart

```ocaml
let () =
  let client = Fxmacrodata.create () in
  match
    Lwt_main.run
      (Fxmacrodata.macro_indicator client ~currency:"usd"
         ~indicator:"inflation" ~start_date:"2026-01-01" ())
  with
  | Ok rows -> Printf.printf "Fetched %d rows\n" (List.length rows)
  | Error e -> prerr_endline (Fxmacrodata.Error.to_string e)
```

Run the bundled example:

```sh
dune exec examples/latest_announcements.exe
```

## Authentication

[Subscribe to FXMacroData](https://fxmacrodata.com/subscribe?utm_source=github&utm_medium=referral&utm_campaign=open_source_integrations&utm_content=ocaml_subscribe) to use non-USD data, full available history, FX, commodities and positioning in your OCaml application. Evaluate the client with public USD data without a key.

For subscription access, pass your account's key explicitly or set an
environment variable — resolution order is `~api_key`, then
`FXMACRODATA_API_KEY`, then `FXMD_API_KEY`:

```ocaml
let client = Fxmacrodata.create ~api_key:"YOUR_KEY" ()
```

The key is sent as an `X-API-Key` header by default; use
`~auth_mode:Fxmacrodata.Query` to send it as an `api_key` query parameter
instead.

## API surface

Typed helpers (all return `(_, Fxmacrodata.Error.t) result Lwt.t`; dates are
`YYYY-MM-DD` strings):

| Function | Endpoint |
|---|---|
| `ping` | `GET /v1/ping` |
| `data_catalogue ~currency` | `GET /v1/data_catalogue/{currency}` |
| `release_calendar ~currency` | `GET /v1/calendar/{currency}` |
| `macro_indicator ~currency ~indicator` | `GET /v1/announcements/{currency}/{indicator}` |
| `forex ~base ~quote` | `GET /v1/forex/{base}/{quote}` |
| `cot ~currency` | `GET /v1/cot/{currency}` |
| `commodity ~indicator` | `GET /v1/commodities/{indicator}` |

Any other endpoint of the [public API](https://fxmacrodata.com/documentation/reference?utm_source=github&utm_medium=referral&utm_campaign=ocaml-fxmacrodata&utm_content=readme) is
reachable through the generic escape hatch:

```ocaml
Fxmacrodata.get_json client ~path:"/v1/market_sessions" ()
```

`get_data` is the same but returns the top-level `data` array of the
response, which is the shape most time-series endpoints use.

Start with `data_catalogue` to discover the exact indicator slugs available
for a currency.

## Development

```sh
opam install . --deps-only --with-test
dune build
dune test
```

Tests run fully offline against an injected stub HTTP function.

## Related

- [Python client](https://github.com/fxmacrodata/fxmacrodata) ·
  [Julia client](https://github.com/fxmacrodata/FXMacroData.jl) ·
  [MCP server](https://github.com/fxmacrodata/mcp-server-fxmacrodata)
- [API documentation](https://fxmacrodata.com/documentation/reference?utm_source=github&utm_medium=referral&utm_campaign=ocaml-fxmacrodata&utm_content=readme)

## License

MIT

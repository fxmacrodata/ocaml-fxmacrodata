(lang dune 3.7)

(name fxmacrodata)

(generate_opam_files true)

(source
 (github fxmacrodata/ocaml-fxmacrodata))

(license MIT)

(authors "FXMacroData <quantdevapp@gmail.com>")

(maintainers "FXMacroData <quantdevapp@gmail.com>")

(homepage "https://fxmacrodata.com")

(documentation "https://fxmacrodata.com/documentation/reference")

(package
 (name fxmacrodata)
 (synopsis
  "OCaml client for the FXMacroData forex and macroeconomic data API")
 (description
  "Client library for the FXMacroData REST API: official-source forex and macroeconomic data covering central-bank announcements, macroeconomic indicator time series, economic release calendars, CFTC Commitment of Traders positioning, commodities, and FX spot-rate history for 18 catalogue currencies. Provides a small typed wrapper with Lwt-based requests, plus a generic get_json escape hatch for any endpoint of the public API.")
 (depends
  (ocaml
   (>= 4.14))
  (cohttp-lwt-unix
   (>= 5.0))
  (cohttp
   (>= 5.0))
  (cohttp-lwt
   (>= 5.0))
  (lwt
   (>= 5.6))
  (uri
   (>= 4.0))
  (yojson
   (>= 2.0))
  (alcotest
   (and
    (>= 1.7)
    :with-test)))
 (tags
  (forex macroeconomics finance "market data" api-client)))

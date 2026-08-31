(** OCaml client for the {{:https://fxmacrodata.com}FXMacroData} API.

    FXMacroData serves official-source forex and macroeconomic data:
    central-bank announcements, macroeconomic indicator time series, economic
    release calendars, CFTC Commitment of Traders positioning, commodities,
    and FX spot-rate history across 18 catalogue currencies.

    {2 Quickstart}

    {[
      let client = Fxmacrodata.create () in
      match
        Lwt_main.run
          (Fxmacrodata.macro_indicator client ~currency:"usd"
             ~indicator:"inflation" ())
      with
      | Ok rows -> Printf.printf "%d rows\n" (List.length rows)
      | Error e -> prerr_endline (Fxmacrodata.Error.to_string e)
    ]}

    Free-tier endpoints work without a key. For keyed access, pass
    [~api_key] to {!create} or set the [FXMACRODATA_API_KEY] (or
    [FXMD_API_KEY]) environment variable.

    API reference: {{:https://fxmacrodata.com/documentation/reference}fxmacrodata.com/documentation/reference} *)

(** Errors returned by every request function. *)
module Error : sig
  type t =
    | Api of {
        status : int;  (** HTTP status code of the error response. *)
        detail : Yojson.Safe.t;
            (** Parsed JSON error payload, or [{"detail": <raw body>}] when
                the body was not JSON. *)
      }
        (** The API answered with a non-2xx status. *)
    | Transport of string
        (** The request failed before an API response was obtained
            (connection failure, timeout, or invalid JSON in a 2xx body). *)

  val to_string : t -> string
end

type http_response = {
  status : int;
  body : string;
}
(** Minimal HTTP response consumed by the client. *)

type http = uri:string -> headers:(string * string) list -> http_response Lwt.t
(** The HTTP GET function used to perform requests. The default
    implementation uses [cohttp-lwt-unix]; tests can inject a stub via
    {!create}'s [?http] argument. *)

type auth_mode =
  | Header  (** Send the key as an [X-API-Key] request header (default). *)
  | Query  (** Send the key as an [api_key] query parameter. *)

type t
(** A configured API client. *)

val default_base_url : string
(** ["https://api.fxmacrodata.com"] *)

val resolve_api_key : ?api_key:string -> unit -> string option
(** Resolve an API key from the explicit value, then the
    [FXMACRODATA_API_KEY] and [FXMD_API_KEY] environment variables. Empty
    strings are treated as absent. *)

val create :
  ?api_key:string ->
  ?base_url:string ->
  ?auth_mode:auth_mode ->
  ?timeout:float ->
  ?http:http ->
  unit ->
  t
(** [create ()] builds a client. [?timeout] is in seconds (default 30) and
    applies to the default HTTP implementation only. A trailing slash on
    [?base_url] is stripped. *)

val get_json :
  t ->
  path:string ->
  ?params:(string * string option) list ->
  unit ->
  (Yojson.Safe.t, Error.t) result Lwt.t
(** Perform a GET request against any API path (e.g.
    [~path:"/v1/market_sessions"]) and return the full JSON response.
    Parameters whose value is [None] are dropped. This is the escape hatch
    for endpoints without a dedicated function below. *)

val get_data :
  t ->
  path:string ->
  ?params:(string * string option) list ->
  unit ->
  (Yojson.Safe.t list, Error.t) result Lwt.t
(** Like {!get_json}, but return the top-level [data] array of the response
    ([[]] when absent or not an array). *)

val ping : t -> (Yojson.Safe.t, Error.t) result Lwt.t
(** [GET /v1/ping] — service health check. *)

val data_catalogue :
  t ->
  currency:string ->
  ?include_coverage:bool ->
  ?include_capabilities:bool ->
  ?indicator:string ->
  unit ->
  (Yojson.Safe.t, Error.t) result Lwt.t
(** [GET /v1/data_catalogue/{currency}] — the indicators published for a
    currency, with units, frequency and coverage metadata.
    [?include_coverage] defaults to [true]. *)

val release_calendar :
  t ->
  currency:string ->
  ?indicator:string ->
  unit ->
  (Yojson.Safe.t list, Error.t) result Lwt.t
(** [GET /v1/calendar/{currency}] — upcoming economic release-calendar rows. *)

val macro_indicator :
  t ->
  currency:string ->
  indicator:string ->
  ?start_date:string ->
  ?end_date:string ->
  unit ->
  (Yojson.Safe.t list, Error.t) result Lwt.t
(** [GET /v1/announcements/{currency}/{indicator}] — macroeconomic indicator
    time-series rows. Dates are [YYYY-MM-DD] strings. *)

val forex :
  t ->
  base:string ->
  quote:string ->
  ?start_date:string ->
  ?end_date:string ->
  unit ->
  (Yojson.Safe.t list, Error.t) result Lwt.t
(** [GET /v1/forex/{base}/{quote}] — FX spot-rate history rows. *)

val cot :
  t ->
  currency:string ->
  ?start_date:string ->
  ?end_date:string ->
  unit ->
  (Yojson.Safe.t list, Error.t) result Lwt.t
(** [GET /v1/cot/{currency}] — CFTC Commitment of Traders positioning rows. *)

val commodity :
  t ->
  indicator:string ->
  ?start_date:string ->
  ?end_date:string ->
  unit ->
  (Yojson.Safe.t list, Error.t) result Lwt.t
(** [GET /v1/commodities/{indicator}] — commodity price history rows. *)

(* OCaml client for the FXMacroData API: https://fxmacrodata.com *)

module Error = struct
  type t =
    | Api of {
        status : int;
        detail : Yojson.Safe.t;
      }
    | Transport of string

  let to_string = function
    | Api { status; detail } ->
        Printf.sprintf "FXMacroData API error %d: %s" status
          (Yojson.Safe.to_string detail)
    | Transport msg -> Printf.sprintf "FXMacroData transport error: %s" msg
end

type http_response = {
  status : int;
  body : string;
}

type http = uri:string -> headers:(string * string) list -> http_response Lwt.t

type auth_mode =
  | Header
  | Query

type t = {
  api_key : string option;
  base_url : string;
  auth_mode : auth_mode;
  http : http;
}

let default_base_url = "https://api.fxmacrodata.com"

let non_empty = function
  | Some "" -> None
  | v -> v

let resolve_api_key ?api_key () =
  match non_empty api_key with
  | Some _ as k -> k
  | None -> (
      match non_empty (Sys.getenv_opt "FXMACRODATA_API_KEY") with
      | Some _ as k -> k
      | None -> non_empty (Sys.getenv_opt "FXMD_API_KEY"))

let default_http ~timeout ~uri ~headers =
  let open Lwt.Infix in
  let request () =
    Cohttp_lwt_unix.Client.get
      ~headers:(Cohttp.Header.of_list headers)
      (Uri.of_string uri)
    >>= fun (resp, body) ->
    Cohttp_lwt.Body.to_string body >>= fun body ->
    Lwt.return
      { status = Cohttp.Code.code_of_status (Cohttp.Response.status resp); body }
  in
  let timed_out () =
    Lwt_unix.sleep timeout >>= fun () ->
    Lwt.fail_with (Printf.sprintf "request timed out after %.0fs" timeout)
  in
  Lwt.pick [ request (); timed_out () ]

let create ?api_key ?(base_url = default_base_url) ?(auth_mode = Header)
    ?(timeout = 30.) ?http () =
  let api_key = resolve_api_key ?api_key () in
  let base_url =
    let n = String.length base_url in
    if n > 0 && base_url.[n - 1] = '/' then String.sub base_url 0 (n - 1)
    else base_url
  in
  let http =
    match http with
    | Some f -> f
    | None -> default_http ~timeout
  in
  { api_key; base_url; auth_mode; http }

let clean_params params =
  List.filter_map (fun (k, v) -> Option.map (fun v -> (k, v)) v) params

let get_json t ~path ?(params = []) () =
  let params = clean_params params in
  let params, headers =
    match (t.api_key, t.auth_mode) with
    | Some key, Query -> (params @ [ ("api_key", key) ], [])
    | Some key, Header -> (params, [ ("X-API-Key", key) ])
    | None, _ -> (params, [])
  in
  let uri =
    let u = Uri.of_string (t.base_url ^ path) in
    Uri.to_string (Uri.with_query' u params)
  in
  Lwt.catch
    (fun () ->
      Lwt.bind (t.http ~uri ~headers) (fun { status; body } ->
          let json =
            match Yojson.Safe.from_string body with
            | json -> Some json
            | exception _ -> None
          in
          if status >= 200 && status < 300 then
            match json with
            | Some j -> Lwt.return (Ok j)
            | None ->
                Lwt.return (Error (Error.Transport "response was not valid JSON"))
          else
            let detail =
              match json with
              | Some j -> j
              | None -> `Assoc [ ("detail", `String body) ]
            in
            Lwt.return (Error (Error.Api { status; detail }))))
    (fun exn -> Lwt.return (Error (Error.Transport (Printexc.to_string exn))))

let get_data t ~path ?params () =
  Lwt.map
    (Result.map (function
      | `Assoc fields -> (
          match List.assoc_opt "data" fields with
          | Some (`List rows) -> rows
          | _ -> [])
      | _ -> []))
    (get_json t ~path ?params ())

let seg s = Uri.pct_encode ~component:`Path (String.lowercase_ascii s)
let opt_lower = Option.map String.lowercase_ascii
let bool_param b = Some (if b then "true" else "false")
let ping t = get_json t ~path:"/v1/ping" ()

let data_catalogue t ~currency ?(include_coverage = true)
    ?(include_capabilities = false) ?indicator () =
  get_json t
    ~path:("/v1/data_catalogue/" ^ seg currency)
    ~params:
      [
        ("include_coverage", bool_param include_coverage);
        ("include_capabilities", bool_param include_capabilities);
        ("indicator", opt_lower indicator);
      ]
    ()

let release_calendar t ~currency ?indicator () =
  get_data t
    ~path:("/v1/calendar/" ^ seg currency)
    ~params:[ ("indicator", opt_lower indicator) ]
    ()

let macro_indicator t ~currency ~indicator ?start_date ?end_date () =
  get_data t
    ~path:(Printf.sprintf "/v1/announcements/%s/%s" (seg currency) (seg indicator))
    ~params:[ ("start_date", start_date); ("end_date", end_date) ]
    ()

let forex t ~base ~quote ?start_date ?end_date () =
  get_data t
    ~path:(Printf.sprintf "/v1/forex/%s/%s" (seg base) (seg quote))
    ~params:[ ("start_date", start_date); ("end_date", end_date) ]
    ()

let cot t ~currency ?start_date ?end_date () =
  get_data t
    ~path:("/v1/cot/" ^ seg currency)
    ~params:[ ("start_date", start_date); ("end_date", end_date) ]
    ()

let commodity t ~indicator ?start_date ?end_date () =
  get_data t
    ~path:("/v1/commodities/" ^ seg indicator)
    ~params:[ ("start_date", start_date); ("end_date", end_date) ]
    ()

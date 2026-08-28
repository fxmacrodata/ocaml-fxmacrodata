(* Offline tests: every request goes through an injected stub HTTP function. *)

let announcements_fixture =
  {|{
  "currency": "usd",
  "indicator": "inflation_rate",
  "data": [
    {"date": "2026-07-15", "value": 2.7, "unit": "percent"},
    {"date": "2026-06-11", "value": 2.4, "unit": "percent"}
  ]
}|}

type captured = {
  mutable uri : string;
  mutable headers : (string * string) list;
}

(* Stub client: records the request and returns the canned response. *)
let stub ?(status = 200) ?(body = "{}") () =
  let cap = { uri = ""; headers = [] } in
  let http ~uri ~headers =
    cap.uri <- uri;
    cap.headers <- headers;
    Lwt.return Fxmacrodata.{ status; body }
  in
  (cap, Fxmacrodata.create ~api_key:"test-key" ~http ())

let run = Lwt_main.run
let query_of cap = Uri.query (Uri.of_string cap.uri)
let path_of cap = Uri.path (Uri.of_string cap.uri)

let check_ok = function
  | Ok v -> v
  | Error e -> Alcotest.failf "expected Ok, got %s" (Fxmacrodata.Error.to_string e)

let test_api_key_resolution () =
  Unix.putenv "FXMACRODATA_API_KEY" "env-primary";
  Unix.putenv "FXMD_API_KEY" "env-fallback";
  Alcotest.(check (option string))
    "explicit wins" (Some "explicit")
    (Fxmacrodata.resolve_api_key ~api_key:"explicit" ());
  Alcotest.(check (option string))
    "primary env var wins over fallback" (Some "env-primary")
    (Fxmacrodata.resolve_api_key ());
  Unix.putenv "FXMACRODATA_API_KEY" "";
  Alcotest.(check (option string))
    "empty primary falls through to fallback" (Some "env-fallback")
    (Fxmacrodata.resolve_api_key ());
  Unix.putenv "FXMD_API_KEY" "";
  Alcotest.(check (option string))
    "all empty resolves to None" None
    (Fxmacrodata.resolve_api_key ())

let test_header_auth_default () =
  let cap, client = stub () in
  let _ = check_ok (run (Fxmacrodata.get_json client ~path:"/v1/ping" ())) in
  Alcotest.(check (option string))
    "X-API-Key header set" (Some "test-key")
    (List.assoc_opt "X-API-Key" cap.headers);
  Alcotest.(check bool)
    "no api_key in query" false
    (List.mem_assoc "api_key" (query_of cap))

let test_query_auth_mode () =
  let cap = { uri = ""; headers = [] } in
  let http ~uri ~headers =
    cap.uri <- uri;
    cap.headers <- headers;
    Lwt.return Fxmacrodata.{ status = 200; body = "{}" }
  in
  let client =
    Fxmacrodata.create ~api_key:"test-key" ~auth_mode:Fxmacrodata.Query ~http ()
  in
  let _ = check_ok (run (Fxmacrodata.get_json client ~path:"/v1/ping" ())) in
  Alcotest.(check (list string))
    "api_key in query" [ "test-key" ]
    (List.assoc "api_key" (query_of cap));
  Alcotest.(check bool)
    "no X-API-Key header" false
    (List.mem_assoc "X-API-Key" cap.headers)

let test_none_params_dropped () =
  let cap, client = stub () in
  let _ =
    check_ok
      (run
         (Fxmacrodata.get_json client ~path:"/v1/x"
            ~params:[ ("kept", Some "1"); ("dropped", None) ]
            ()))
  in
  let q = query_of cap in
  Alcotest.(check bool) "kept present" true (List.mem_assoc "kept" q);
  Alcotest.(check bool) "dropped absent" false (List.mem_assoc "dropped" q)

let test_api_error_json_detail () =
  let _, client = stub ~status:404 ~body:{|{"detail": "not found"}|} () in
  match run (Fxmacrodata.get_json client ~path:"/v1/x" ()) with
  | Error (Fxmacrodata.Error.Api { status; detail }) ->
      Alcotest.(check int) "status" 404 status;
      Alcotest.(check string)
        "detail" {|{"detail":"not found"}|}
        (Yojson.Safe.to_string detail)
  | other ->
      Alcotest.failf "expected Api error, got %s"
        (match other with
        | Ok _ -> "Ok"
        | Error e -> Fxmacrodata.Error.to_string e)

let test_api_error_non_json_body () =
  let _, client = stub ~status:502 ~body:"Bad Gateway" () in
  match run (Fxmacrodata.get_json client ~path:"/v1/x" ()) with
  | Error (Fxmacrodata.Error.Api { status; detail }) ->
      Alcotest.(check int) "status" 502 status;
      Alcotest.(check string)
        "raw body wrapped as detail" {|{"detail":"Bad Gateway"}|}
        (Yojson.Safe.to_string detail)
  | _ -> Alcotest.fail "expected Api error"

let test_invalid_json_success_body () =
  let _, client = stub ~status:200 ~body:"<html>oops</html>" () in
  match run (Fxmacrodata.get_json client ~path:"/v1/x" ()) with
  | Error (Fxmacrodata.Error.Transport _) -> ()
  | _ -> Alcotest.fail "expected Transport error on non-JSON 2xx body"

let test_get_data_extracts_rows () =
  let _, client = stub ~body:announcements_fixture () in
  let rows = check_ok (run (Fxmacrodata.get_data client ~path:"/v1/x" ())) in
  Alcotest.(check int) "two rows" 2 (List.length rows)

let test_get_data_missing_field () =
  let _, client = stub ~body:{|{"currency": "usd"}|} () in
  let rows = check_ok (run (Fxmacrodata.get_data client ~path:"/v1/x" ())) in
  Alcotest.(check int) "empty when data absent" 0 (List.length rows)

let test_macro_indicator_request_shape () =
  let cap, client = stub ~body:announcements_fixture () in
  let rows =
    check_ok
      (run
         (Fxmacrodata.macro_indicator client ~currency:"USD"
            ~indicator:"Inflation_Rate" ~start_date:"2026-01-01" ()))
  in
  Alcotest.(check int) "rows parsed" 2 (List.length rows);
  Alcotest.(check string)
    "path lowercased" "/api/v1/announcements/usd/inflation_rate" (path_of cap);
  let q = query_of cap in
  Alcotest.(check (list string))
    "start_date sent" [ "2026-01-01" ]
    (List.assoc "start_date" q);
  Alcotest.(check bool) "end_date absent" false (List.mem_assoc "end_date" q)

let test_forex_request_shape () =
  let cap, client = stub ~body:{|{"data": []}|} () in
  let _ = check_ok (run (Fxmacrodata.forex client ~base:"EUR" ~quote:"USD" ())) in
  Alcotest.(check string) "path" "/api/v1/forex/eur/usd" (path_of cap)

let test_data_catalogue_bool_params () =
  let cap, client = stub () in
  let _ =
    check_ok (run (Fxmacrodata.data_catalogue client ~currency:"aud" ()))
  in
  let q = query_of cap in
  Alcotest.(check (list string))
    "include_coverage defaults true" [ "true" ]
    (List.assoc "include_coverage" q);
  Alcotest.(check (list string))
    "include_capabilities defaults false" [ "false" ]
    (List.assoc "include_capabilities" q)

let test_base_url_trailing_slash () =
  let cap = { uri = ""; headers = [] } in
  let http ~uri ~headers =
    cap.uri <- uri;
    cap.headers <- headers;
    Lwt.return Fxmacrodata.{ status = 200; body = "{}" }
  in
  let client =
    Fxmacrodata.create ~api_key:"k" ~base_url:"https://example.test/api/" ~http ()
  in
  let _ = check_ok (run (Fxmacrodata.ping client)) in
  Alcotest.(check string) "no double slash" "/api/v1/ping" (path_of cap)

let () =
  Alcotest.run "fxmacrodata"
    [
      ( "auth",
        [
          Alcotest.test_case "api key resolution" `Quick test_api_key_resolution;
          Alcotest.test_case "header mode default" `Quick test_header_auth_default;
          Alcotest.test_case "query mode" `Quick test_query_auth_mode;
        ] );
      ( "requests",
        [
          Alcotest.test_case "None params dropped" `Quick test_none_params_dropped;
          Alcotest.test_case "macro_indicator shape" `Quick
            test_macro_indicator_request_shape;
          Alcotest.test_case "forex shape" `Quick test_forex_request_shape;
          Alcotest.test_case "data_catalogue bools" `Quick
            test_data_catalogue_bool_params;
          Alcotest.test_case "trailing slash stripped" `Quick
            test_base_url_trailing_slash;
        ] );
      ( "responses",
        [
          Alcotest.test_case "api error with JSON detail" `Quick
            test_api_error_json_detail;
          Alcotest.test_case "api error with non-JSON body" `Quick
            test_api_error_non_json_body;
          Alcotest.test_case "invalid JSON on 2xx" `Quick
            test_invalid_json_success_body;
          Alcotest.test_case "get_data extracts rows" `Quick
            test_get_data_extracts_rows;
          Alcotest.test_case "get_data missing field" `Quick
            test_get_data_missing_field;
        ] );
    ]

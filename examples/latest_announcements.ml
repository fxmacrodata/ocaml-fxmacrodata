(* Fetch recent USD inflation announcements and print the first rows.
   Usage: dune exec examples/latest_announcements.exe *)

let () =
  let client = Fxmacrodata.create () in
  match
    Lwt_main.run
      (Fxmacrodata.macro_indicator client ~currency:"usd"
         ~indicator:"inflation" ~start_date:"2026-01-01" ())
  with
  | Ok rows ->
      Printf.printf "Fetched %d rows\n" (List.length rows);
      List.iteri
        (fun i row ->
          if i < 3 then print_endline (Yojson.Safe.pretty_to_string row))
        rows
  | Error e ->
      prerr_endline (Fxmacrodata.Error.to_string e);
      exit 1

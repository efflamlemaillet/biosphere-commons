open Core.Std
open Cohttp
open Cohttp_lwt_unix

let ( >>= ) = Lwt.( >>= )
let ( >>| ) = Lwt.( >|= )

type credentials = {
  username : string ;
  password : string ;
}

type token = string


(* let extract_1_0 cstr alist = *)
(*   let attrs = Stringext.split_trim_left cstr ~on:",;" ~trim:" \t" in *)
(*   let attrs = List.map ~f:(fun attr -> *)
(*       match Stringext.split ~on:'=' attr with *)
(*         | [] -> ("","") *)
(*         | n::v -> (n,String.concat ~sep:"=" v) *)
(*     ) attrs in *)
(*     try *)
(*       let cookie = List.hd_exn attrs in *)
(*       let attrs = List.map ~f:(fun (n,v) -> (String.lowercase n, v)) *)
(*         (List.tl_exn attrs) in *)
(*       let path = *)
(*         try *)
(*           let v = List.Assoc.find_exn  attrs "path" in *)
(*           if v = "" || v.[0] <> '/' *)
(*           then raise Not_found *)
(*           else Some v *)
(*         with Not_found -> None *)
(*       in *)
(*       let domain = *)
(*         try *)
(*           let v = List.Assoc.find_exn  attrs "domain" in *)
(*           if v = "" then raise Not_found *)
(*           else Some *)
(*             (String.lowercase *)
(*                (if v.[0] = '.' then Stringext.string_after v 1 else v)) *)
(*         with Not_found -> None *)
(*       in *)
(*       (\* TODO: trim wsp *\) *)
(*       (fst cookie, { *)
(*         Cookie.cookie; *)
(*         (\* TODO: respect expires attribute *\) *)
(*         expiration = `Session; *)
(*         domain; *)
(*         path; *)
(*         http_only=List.mem_assoc "httponly" attrs; *)
(*         secure = List.mem_assoc "secure" attrs; *)
(*       })::alist *)
(*     with (Failure "hd") -> alist *)


let extract hdr =
    List.fold_left
      ~f:(fun acc header ->
          let comps = Stringext.split_trim_left ~on:";" ~trim:" \t" header in
          (* We don't handle $Path, $Domain, $Port, $Version (or $anything
             $else) *)
          let cookies = List.filter ~f:(fun s -> s.[0] <> '$') comps in
          let split_pair nvp =
            match Stringext.split ~on:'=' nvp ~max:2 with
            | [] -> ("","")
            | n :: [] -> (n, "")
            | n :: v :: _ -> (n, v)
          in (List.map ~f:split_pair cookies) @ acc
      ) ~init:[] (Header.get_multi hdr "set-cookie")


let login { username ; password } url =
  let uri = Uri.of_string url in
  let headers = Header.of_list [ "Content-Type", "application/x-www-form-urlencoded" ] in
  let body =
    sprintf "username=%s&password=%s" username password
    |> Cohttp_lwt_body.of_string
  in
  Client.post ~headers ~body uri >>| fun (resp, body) ->
  Response.headers resp
  |> fun headers ->
  let cookies = extract headers in
  List.Assoc.find_exn cookies "com.sixsq.slipstream.cookie"
  |> String.lsplit2_exn ~on:'='
  |> snd
  |> fun x -> print_endline x ; x

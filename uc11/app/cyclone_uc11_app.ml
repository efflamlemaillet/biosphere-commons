let () =
  let open Cyclone_uc11.Slipstream_api in
  login
    { username = Sys.argv.(1) ; password = Sys.argv.(2) }
    "https://nuv.la/auth/login"
  |> Lwt_unix.run
  |> ignore

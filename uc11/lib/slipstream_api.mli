type credentials = {
  login : string ;
  password : string ;
}

type token

val login :
  credentials ->
  string ->
  token Lwt.t


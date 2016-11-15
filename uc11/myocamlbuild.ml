open Printf
open Solvuu_build.Std
open Solvuu_build.Util

let project_name = "biocaml"
let version = "dev"

let annot = ()
let bin_annot = ()
let g = ()
let short_paths = ()
let thread = ()
let w = "A-4-33-41-42-44-45-48"

let lib ?findlib_deps ?internal_deps ?build_if ?ml_files lib_name
  : Project.item
  =
  Project.lib (sprintf "%s_%s" project_name lib_name)
    ~annot ~bin_annot ~g ~short_paths ~thread ~w
    ~pkg:(sprintf "%s.%s" project_name lib_name)
    ~dir:(sprintf "lib/%s" lib_name)
    ~style:(`Pack (sprintf "%s_%s" project_name lib_name))
    ~build_plugin:false (* solvuu-build doesn't implement plugin
                           compilation in case there are C files,
                           which is the case of biocaml_unix. Since
                           most other libs depend on it, we simply
                           refrain from compiling plugins for now.  *)
    ?findlib_deps
    ?internal_deps
    ?ml_files

let app ?internal_deps name : Project.item =
  Project.app name
    ~annot ~bin_annot ~g ~short_paths ~thread ~w
    ~file:(sprintf "app/%s.ml" name)
    ?internal_deps

let cyclone_uc11_lib =
  Project.lib "cyclone_uc11"
    ~annot ~bin_annot ~g ~short_paths ~thread ~w
    ~pkg:"cyclone_uc11"
    ~dir:"lib"
    ~style:(`Pack "Cyclone_uc11")
    ~findlib_deps:["cohttp.lwt"]


let cyclone_uc11_app =
  app "cyclone_uc11_app"

let items =
  [
   cyclone_uc11_lib ; cyclone_uc11_app ;
  ]

;;
let () =
  let open Solvuu_build.Std.Project in

  (* Compute graph to check for cycles and other errors. *)
  ignore (Graph.of_list items);

  let libs = filter_libs items in
  let apps = filter_apps items in

  Ocamlbuild_plugin.dispatch @@ function
  | Ocamlbuild_plugin.After_rules -> (
      Ocamlbuild_plugin.clear_rules();

      Tools.m4_rule ()
        ~_D:[
          "GIT_COMMIT", Some (match Tools.git_last_commit() with
            | None -> "None"
            | Some x -> sprintf "Some \"%s\"" x
          );
          "VERSION", Some version;
        ];

      List.iter libs ~f:build_lib;
      List.iter apps ~f:build_app;

      build_static_file ".merlin" (merlin_file items);
      build_static_file ".ocamlinit"
        (ocamlinit_file items ~postfix:["open Biocaml_unix.Std"]);
      build_static_file "project.mk"
        (makefile items ~project_name);
      (
        match meta_file ~version libs with
        | None -> ()
        | Some x -> Findlib.build_meta_file x
      );
      build_static_file (sprintf "%s.install" project_name)
        (install_file items);
    )
  | _ -> ()

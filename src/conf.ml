(* For staging arch-specific builds before creating the manifest. *)
let staging_repo = "ocurrent/opam-staging"

let public_repo = "ocaml/opam"

let password_path =
  let open Fpath in
  let root = v (if Sys.win32 then "C:\\ProgramData\\Docker" else "/run") in
  root / "secrets" / "ocurrent-hub" |> to_string

module Capnp = struct
  (* Cap'n Proto RPC is enabled by passing --capnp-public-address. These values are hard-coded
     (because they're just internal to the Docker container). *)
  let secret_key = "/capnp-secrets/secret-key.pem"
  let cap_file = "/capnp-secrets/base-images.cap"
  let internal_port = 9000
end

let auth =
  if Sys.file_exists password_path then (
    let ch = open_in_bin password_path in
    let len = in_channel_length ch in
    let password = really_input_string ch len |> String.trim in
    close_in ch;
    Some ("ocurrent", password)
  ) else (
    Fmt.pr "Password file %S not found; images will not be pushed to hub@." password_path;
    None
  )

let pool_name os_family arch =
  let os_str = match os_family with
  | `Windows | `Cygwin -> "windows"
  | `Linux -> "linux" in
  let arch_str = match arch with
  | `X86_64 | `I386     -> "x86_64"
  | `Aarch64 | `Aarch32 -> "arm64"
  | `Ppc64le            -> "ppc64" in
  os_str ^ "-" ^ arch_str

let switches ~arch ~distro =
  let is_tier1 = List.mem distro (Dockerfile_distro.active_tier1_distros arch) in
  let main_switches =
    Ocaml_version.Releases.recent_with_dev
    |> List.filter (fun ov -> Dockerfile_distro.distro_supported_on arch ov distro)
  in
  if is_tier1 then (
    List.map (Ocaml_version.Opam.V2.switches arch) main_switches |> List.concat
  ) else (
    main_switches
  )

(* We can't get the active distros directly, but assume x86_64 is a superset of everything else. *)
let distros = Dockerfile_distro.(active_distros `X86_64 |> List.filter (fun d -> os_family_of_distro d = `Linux))

let arches_for ~distro = Dockerfile_distro.distro_arches Ocaml_version.Releases.latest distro

(* For testing, you can uncomment these lines to limit the number of combinations: *)

(*
let distros = ignore distros; [`Debian `V10]
let switches ~arch:_ ~distro:_ = ignore switches; Ocaml_version.Releases.[v4_08]
let arches_for ~distro:_ = ignore arches_for; [`X86_64]
*)

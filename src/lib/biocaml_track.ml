open Biocaml_internal_pervasives
open Result
module Wig = Biocaml_wig
module Gff = Biocaml_gff
module Bed = Biocaml_bed

type t = [
| `track of (string * string) list
| `comment of string
| `browser of
    [ `position of string * int * int | `hide of [`all] | `unknown of string ]
]
type 'a content = [
| `content of 'a
]
type track = t

module Error = struct
  type parsing =
    [ `incomplete_input of Biocaml_pos.t * string list * string option
    | `wrong_browser_position of Biocaml_pos.t * string
    | `wrong_key_value_format of (string * string) list * string * string ]
  with sexp

  type t = [ parsing ] with sexp

end


module Transform = struct

  (*
    browser position chr19:49304200-49310700
    browser hide all
  *)
  let parse_chormpos position s =
    try begin match String.rindex s ':' with
    | Some colon ->
      let name = String.slice s 0 colon in
      begin match String.rindex s '-' with
      | Some dash ->
        let start = String.slice s (colon + 1) dash |! Int.of_string in
        let stop =  String.slice s (dash + 1) (String.length s) |! Int.of_string in
        return (`browser (`position (name, start, stop)))
      | None -> failwith "A"
      end
    | None -> failwith "B"
    end
    with
      e -> fail (`wrong_browser_position (position, s))

  let parse_browser position line =
    let tokens =
      String.chop_prefix ~prefix:"browser " line
      |! Option.value ~default:""
      |! String.split_on_chars ~on:[' '; '\t'; '\r']
      |! List.filter ~f:((<>) "") in
    begin match tokens with
    | "position" :: pos :: [] -> parse_chormpos position pos
    | "hide" :: "all" :: [] -> return (`browser (`hide `all))
    | any -> return (`browser (`unknown line))
    end

  let parse_track position stripped =
    let rec loop s acc =
      match Parse.escapable_string s ~stop_before:['='] with
      | (tag, Some '=', rest) ->
        begin match Parse.escapable_string rest ~stop_before:[' '; '\t'] with
        | (value, _, rest) ->
          let str = String.strip rest in
          if str = "" then return ((tag, value) :: acc)
          else loop str ((tag, value) :: acc)
        end
      | (str, _, rest) -> fail (`wrong_key_value_format (List.rev acc, str, rest))
    in
    loop stripped []
    >>= fun kv ->
    return (`track (List.rev kv))

  let rec next p =
    let open Biocaml_lines.Buffer in
    match (next_line p :> string option) with
    | None -> `not_ready
    | Some "" -> next p
    | Some l when String.(is_prefix (strip l) ~prefix:"#") ->
      output_ok (`comment String.(sub l ~pos:1 ~len:(length l - 1)))
    | Some l when String.strip l = "track"-> output_ok (`track [])
    | Some l when String.strip l = "browser" -> output_ok (`browser (`unknown l))
    | Some l when String.(is_prefix (strip l) ~prefix:"track ") ->
      parse_track (current_position p)
        (String.chop_prefix_exn ~prefix:"track " l |! String.strip)
      |! output_result
    | Some l when String.(is_prefix (strip l) ~prefix:"browser ") ->
      parse_browser (current_position p) l |! output_result
    | Some l -> output_ok (`content l)

  let string_to_string_content ?filename () =
    let name = sprintf "track_parser:%s" Option.(value ~default:"<>" filename) in
    Biocaml_lines.Transform.make_merge_error ~name ?filename ~next ()

  let needs_escaping s =
    String.exists s
      ~f:(function 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> false | _ -> true)
  let potentially_escape s =
    if needs_escaping s then sprintf "%S" s else s

  let string_content_to_string ?(add_content_new_line=true) () =
    let to_string = function
      | `comment c -> sprintf "#%s\n" c
      | `track l ->
        sprintf "track %s\n"
          (List.map l (fun (k,v) ->
            sprintf "%s=%s" (potentially_escape k) (potentially_escape v))
            |! String.concat ~sep:" ")
      | `browser (`hide `all) ->
        "browser hide all\n"
      | `browser (`position (n, s, e)) ->
        sprintf "browser position %s:%d-%d\n" n s e
      | `browser (`unknown s) -> sprintf "browser %s\n" s
      | `content s ->
        if add_content_new_line then s ^ "\n" else s in
    Biocaml_transform.of_function ~name:"track_to_string" to_string

  let embed_parser ?filename =
    let track_parser = string_to_string_content ?filename () in
    Biocaml_transform.filter_compose
      track_parser
      ~destruct:(function
      | Ok (`content s) -> `transform (s ^ "\n")
      | Ok (`track _) | Ok (`browser _) | Ok (`comment _)
      | Error _ as n -> `bypass n)

  type wig_parser_error = [ Error.parsing | Wig.Error.parsing ]
  type wig_t = [ track | Wig.item]

  let string_to_wig ?filename () =
    let wig_parser =
      Wig.Transform.string_to_item ?filename () in
    embed_parser ?filename
      (*
    let track_parser = string_to_string_content ?filename () in
    Biocaml_transform.filter_compose
      track_parser
      ~destruct:(function
      | Ok (`content s) -> `Yes (s ^ "\n")
      | Ok (`track _) | Ok (`browser _) | Ok (`comment _)
      | Error _ as n -> `No n) *)
      wig_parser
      ~reconstruct:(function
      | `bypassed (Ok f) -> Ok (f :> wig_t)
      | `bypassed (Error f) -> Error (f :> [> wig_parser_error])
      | `transformed (Ok o) -> Ok (o :> wig_t)
      | `transformed (Error e) -> Error (e :> [> wig_parser_error]))

  type gff_parse_error = [Error.parsing | Gff.Error.parsing]
  type gff_t = [track | Gff.item]
  let string_to_gff ?filename ~tags () =
    let gff = Gff.Transform.string_to_item ?filename () in
    embed_parser  ?filename (gff ~tags)
      ~reconstruct:(function
      | `bypassed (Ok f) -> Ok (f :> gff_t)
      | `bypassed (Error f) -> Error (f :> [> gff_parse_error])
      | `transformed (Ok o) -> Ok (o :> gff_t)
      | `transformed (Error e) -> Error (e :> [> gff_parse_error]))

  type bed_parse_error = [Error.parsing| Bed.Error.parsing]
  type bed_t = [track |  Bed.item content ]

  let string_to_bed ?filename  ?more_columns  () =
    let bed = Bed.Transform.string_to_item ?more_columns () in
    embed_parser  ?filename bed
      ~reconstruct:(function
      | `bypassed (Ok f) -> Ok (f :> bed_t)
      | `bypassed (Error f) -> Error (f :> [> bed_parse_error])
      | `transformed (Ok o) -> Ok (`content o :> bed_t)
      | `transformed (Error e) -> Error (e :> [> bed_parse_error]))


  let make_printer p ~split () =
    let track = string_content_to_string ~add_content_new_line:false () in
    Biocaml_transform.(
      compose
        (split_and_merge (identity ()) p
           ~merge:(function `left s -> s | `right r -> `content r)
           ~split)
        track)

  let wig_to_string () =
    let wig = Wig.Transform.item_to_string () in
    make_printer wig ()
      ~split:(function
      | `comment _ | `track _ | `browser _ as x -> `left x
      | #Wig.item as y -> `right y)

  let gff_to_string ~tags () =
    let gff = Gff.Transform.item_to_string ~tags () in
    make_printer gff ()
      ~split:(function
      | `comment _ | `track _ | `browser _ as x -> `left x
      | #Gff.item as y -> `right y)

  let bed_to_string () =
    let bed = Bed.Transform.item_to_string () in
    make_printer bed ()
      ~split:(function
      | `comment _ | `track _ | `browser _ as x -> `left x
      | `content y -> `right y)

end

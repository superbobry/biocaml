(** FASTA files. The FASTA family of file formats has different
    incompatible descriptions
    ({{:https://www.proteomecommons.org/tranche/examples/proteomecommons-fasta/fasta.jsp
    }1}, {{:http://zhanglab.ccmb.med.umich.edu/FASTA/}2},
    {{:http://en.wikipedia.org/wiki/FASTA_format}3}, etc.). Roughly
    FASTA files are in the format:

    {v
    # comment
    # comment
    ...
    >header
    sequence
    >header
    sequence
    ...
    v}

    where the sequence may span multiple lines, and a ';' may be used
    instead of '#' to start comments.
    
    Header lines begin with the '>' character. It is often considered
    that all characters until the first whitespace define the {i name}
    of the content, and any characters beyond that define additional
    information in a format specific to the file provider.
    
    Sequence are most often a sequence of characters denoting
    nucleotides or amino acids. However, sometimes FASTA files provide
    quality scores, either as ASCII encoded, e.g. as supported by
    modules {!module: Biocaml_phred_score} and {!module:
    Biocaml_solexa_score}, or as space-separated integers.

    Thus, the FASTA format is really a family of formats with a fairly
    loose specification of the header and content formats. The only
    consistently followed meaning of the format is:

    - the file can begin with comment lines that begin with a '#' or
    ';' character and/or all white-space lines

    - the header lines begins with the '>' character, is followed
    optionally by whitespace, and then contains some string

    - each header line is followed by a sequence of characters or
    space-separated integers, often just one line but allowed to span
    multiple lines

    - and this alternating pair of header/sequence lines can occur
    repeatedly.

    Names used throughout this module use [sequence] to generically
    mean either kind of data found in the sequence lines, [char_seq]
    to mean specifically a sequence of characters, and [int_seq] to
    mean specifically a sequence of integers.

    Parsing functions throughout this module take the following
    optional arguments:

    - [filename] - used only for error messages when the data source
    is not the file.

    - [pedantic] - if true, which is the default, report more
    errors: Biocaml_transform.no_error lines, non standard
    characters.

    - [sharp_comments] and [semicolon_comments] - if true, allow
    comments beginning with a '#' or ';' character,
    respectively. Setting both to true is okay, although it is not
    recommended to have such files. Setting both to false implies that
    comments are disallowed.

*)

type char_seq = string
type int_seq = int list

type 'a item = {
  header : string;
  sequence : 'a;
}

(** Errors. All errors generated by any function in the [Fasta] module
    are defined here. Type [t] is the union of all errors, and subsets
    of this are defined as needed to specify precise return types for
    various functions.

    - [`empty_line pos] - an empty line was found in a position [pos]
    where it is not allowed.

    - [`incomplete_input (lines,s)] - the input ended
    prematurely. Trailing contents, which cannot be used to fully
    construct an item, are provided: [lines] is the complete lines
    parsed and [s] is any final string not ending in a newline.

    - [`malformed_partial_sequence s] - indicates that [s] could not
    be parsed into a valid (partial) sequence value.

    - [`unnamed_char_seq x] - a [char_seq] value [x] was found without
    a preceding header section.

    - [`unnamed_int_seq x] - an [int_seq] value [x] was found without
    a preceding header section.

*)
module Error : sig

  (** Errors raised when converting a string to a {!type:
      raw_item}. *)
  type string_to_raw_item = [
  | `empty_line of Biocaml_pos.t
  | `incomplete_input of Biocaml_pos.t * string list * string option
  | `malformed_partial_sequence of string
  ]

  (** Union of all errors. *)
  type t = [
    string_to_raw_item
  | `unnamed_char_seq of char_seq
  | `unnamed_int_seq of int_seq
  ]


  (** {8 S-expressions} *)

  val sexp_of_string_to_raw_item : string_to_raw_item -> Sexplib.Sexp.t
  val string_to_raw_item_of_sexp : Sexplib.Sexp.t -> string_to_raw_item
  val string_to_raw_item_of_sexp__ : Sexplib.Sexp.t -> string_to_raw_item
  val sexp_of_t : t -> Sexplib.Sexp.t
  val t_of_sexp : Sexplib.Sexp.t -> t
  val t_of_sexp__ : Sexplib.Sexp.t -> t

end

exception Error of Error.t

val in_channel_to_char_seq_item_stream :
  ?filename:string ->
  ?pedantic:bool ->
  ?sharp_comments:bool ->
  ?semicolon_comments:bool ->
  in_channel ->
  char_seq item Stream.t
    (** Returns a stream of [char_seq item]s. Initial comments are
        discarded. @raise Error in case of any errors. *)

val in_channel_to_int_seq_item_stream :
  ?filename:string ->
  ?pedantic:bool ->
  ?sharp_comments:bool ->
  ?semicolon_comments:bool ->
  in_channel ->
  int_seq item Stream.t
    (** Returns a stream of [int_seq item]s. Initial comments are
        discarded. @raise Error in case of any errors. *)

module Result : sig

  val in_channel_to_char_seq_item_stream :
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    in_channel ->
    (char_seq item, Error.t) Core.Result.t Stream.t

  val in_channel_to_int_seq_item_stream :
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    in_channel ->
    (int_seq item, Error.t) Core.Result.t Stream.t

end

(** Low-level transforms. *)
module Transform: sig

  (** Lowest level items parsed by this module:
      
      - [`comment _] - a single comment line without the final
      newline.
      
      - [`header _] - a single header line without the initial '>',
      whitespace following this, nor final newline.
      
      - [`partial_sequence _] - either a sequence of characters,
      represented as a string, or a sequence of space separated
      integers, represented by an [int list]. The value does not
      necessarily carry the complete content associated with a
      header. It may be only part of the sequence, which can be useful
      for files with large sequences (e.g. genomic sequence
      files).  *)
  type 'a raw_item = [
  | `comment of string
  | `header of string
  | `partial_sequence of 'a
  ]


  (** {9 [char_seq] parsers} *)

  val string_to_char_seq_raw_item:
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    unit ->
    (string, (char_seq raw_item, Error.t) Core.Result.t) Biocaml_transform.t
      (** Parse a stream of strings as a char_seq FASTA file. *)

  val char_seq_raw_item_to_item:
    unit -> 
    (char_seq raw_item,
    (char_seq item, [ `unnamed_char_seq of char_seq ]) Core.Result.t)
      Biocaml_transform.t
      (** Aggregate a stream of FASTA [char_seq raw_item]s into [char_seq
          item]s. Comments are discared. *)


  (** {9 [char_seq] unparsers} *)

  val char_seq_item_to_raw_item: ?items_per_line:int -> unit ->
    (char_seq item, char_seq raw_item) Biocaml_transform.t
      (** Cut a stream of [char_seq item]s into a stream of [char_seq
          raw_item]s, where lines are cut at [items_per_line]
          characters (default 80). *)

  val char_seq_raw_item_to_string:
    ?comment_char:char ->
    unit ->
    (char_seq raw_item, string) Biocaml_transform.t
      (** Print [char_seq item]s. Comments will be ignored if
          [comment_char] is omitted. *)


  (** {9 [int_seq] parsers} *)

  val string_to_int_seq_raw_item:
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    unit ->
    (string, (int_seq raw_item, Error.t) Core.Result.t) Biocaml_transform.t
      (** Parse a stream of strings as an int_seq FASTA file. *)

  val int_seq_raw_item_to_item:
    unit -> 
    (int_seq raw_item,
    (int_seq item, [ `unnamed_int_seq of int_seq ]) Core.Result.t)
      Biocaml_transform.t
      (** Aggregate a stream of FASTA [int_seq raw_item]s into [int_seq
          item]s. Comments are discared. *)


  (** {9 [int_seq] unparsers} *)

  val int_seq_item_to_raw_item: ?items_per_line:int -> unit ->
    (int_seq item, int_seq raw_item) Biocaml_transform.t
      (** Cut a stream of [int_seq item]s into a stream of [int_seq
          raw_item]s, where lines are cut at [items_per_line] integers
          (default 27). *)

  val int_seq_raw_item_to_string:
    ?comment_char:char ->
    unit ->
    (int_seq raw_item, string) Biocaml_transform.t
      (** Print [int_seq item]s. Comments will be ignored if
          [comment_char] is omitted. *)


  (** {8 S-expressions} *)

  val sexp_of_raw_item : ('a -> Sexplib.Sexp.t) -> 'a raw_item -> Sexplib.Sexp.t
  val raw_item_of_sexp : (Sexplib.Sexp.t -> 'a) -> Sexplib.Sexp.t -> 'a raw_item
  val raw_item_of_sexp__ : (Sexplib.Sexp.t -> 'a) -> Sexplib.Sexp.t -> 'a raw_item

end


(** {8 S-expressions} *)

val sexp_of_char_seq : char_seq -> Sexplib.Sexp.t
val char_seq_of_sexp : Sexplib.Sexp.t -> char_seq
val sexp_of_int_seq : int_seq -> Sexplib.Sexp.t
val int_seq_of_sexp : Sexplib.Sexp.t -> int_seq
val sexp_of_item : ('a -> Sexplib.Sexp.t) -> 'a item -> Sexplib.Sexp.t
val item_of_sexp : (Sexplib.Sexp.t -> 'a) -> Sexplib.Sexp.t -> 'a item

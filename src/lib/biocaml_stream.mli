(** This module is an enhancement of
    {{:http://caml.inria.fr/pub/docs/manual-ocaml/libref/Stream.html}the
    stdlib's [Stream] module}, whose specification and documentation
    is largely inspired from
    {{:http://ocaml-batteries-team.github.com/batteries-included/hdoc2/BatEnum.html}Batteries's
    [Enum] module}. However, it is written in a more core-styled way. *)

open Core.Std

include module type of Stream with type 'a t = 'a Stream.t

(** A signature for data structures which may be converted to and from [Stream.t].
      
    If you create a new data structure, you should make it compatible
    with [Streamable].
*)
module type Streamable = sig
  type 'a streamable
  (** The type of the datastructure *)
    
  val stream : 'a streamable -> 'a t
  (** Return an enumeration of the elements of the data structure *)
    
  val of_stream : 'a t -> 'a streamable
  (** Build a data structure from an enumeration *)
end

include Streamable with type 'a streamable = 'a t

val iter : 'a t -> f:('a -> unit) -> unit

exception Expected_streams_of_equal_length

val iter2_exn : 'a t -> 'b t -> f:('a -> 'b -> unit) -> unit
  (** [iter2_exn a b ~f] calls in turn [f a1 b1; ...; f an bn]. @raise
      [Expected_streams_of_equal_length] if the two streams have
      different lengths, and no guarantee about which elements were
      consumed. *)
val iter2 : 'a t -> 'b t -> f:('a -> 'b -> unit) -> unit
  (** Same as [iter2_exn] except that it doesn't raise an exception if
      the two streams have different lengths. *)

val exists: 'a t -> f:('a -> bool) -> bool
  (** [exists e ~f] returns [true] if there is some [x] in [e] such
      that [f x]*)

val for_all: 'a t -> f:('a -> bool) -> bool
  (** [for_all e ~f] returns [true] if for every [x] in [e], [f x] is true*)

val fold : 'a t -> init:'b -> f:('b -> 'a -> 'b) -> 'b

val reduce : 'a t -> f:('a -> 'a -> 'a) -> 'a

val sum : int t -> int
val fsum : float t -> float 

val fold2_exn : 'a t -> 'b t -> init:'c -> f:('c -> 'a -> 'b -> 'c) -> 'c
val fold2 : 'a t -> 'b t -> init:'c -> f:('c -> 'a -> 'b -> 'c) -> 'c

val scanl : 'a t -> init:'b -> f:('b -> 'a -> 'b) -> 'b t
  (** A variant of [fold] producing a stream of its intermediate
      values.  If [e] contains [x0], [x1], ..., [scanl f init e] is
      the stream containing [init], [f init x0], [f (f init x0) x1],
      [f (f (f init x0) x1) x2], ... *)

val scan : 'a t -> f:('a -> 'a -> 'a) -> 'a t
  (** [scan] is similar to [scanl] but without the [init] value: if [e]
      contains [x0], [x1], [x2] ..., [scan e ~f] is the enumeration containing
      [x0], [f x0 x1], [f (f x0 x1) x2]...

      For instance, [scan (1 -- 10) ~f:( * )] will produce an enumeration
      containing the successive values of the factorial function.*)

val iteri : 'a t -> f:(int -> 'a -> unit) -> unit
val iter2i_exn : 'a t -> 'b t -> f:(int -> int -> 'a -> 'b -> unit) -> unit
val iter2i : 'a t -> 'b t -> f:(int -> int -> 'a -> 'b -> unit) -> unit
val foldi : 'a t -> init:'b -> f:(int -> 'b -> 'a -> 'b) -> 'b
val fold2i_exn : 'a t -> 'b t -> init:'c -> f:(int -> int -> 'c -> 'a -> 'b -> 'c) -> 'c
val fold2i : 'a t -> 'b t -> init:'c -> f:(int -> int -> 'c -> 'a -> 'b -> 'c) -> 'c

val find : 'a t -> f:('a -> bool) -> 'a option
  (** [find e ~f] returns either [Some x] where [x] is the first
      element of [e] such that [f x] returns [true], consuming the
      stream up to and including the found element, or [None] if no
      such element exists in the stream, consuming the whole stream in
      the search.

      Since [find] (eagerly) consumes a prefix of the stream, it
      can be used several times on the same stream to find the
      next element. *)


val find_exn : 'a t -> f:('a -> bool) -> 'a
val find_map : 'a t -> f:('a -> 'b option) -> 'b option

val next: 'a t -> 'a option
val next_exn: 'a t -> 'a
val is_empty : 'a t -> bool

  (** {6 Prefix and suffix} *)
val take : int -> 'a t -> 'a t
val take_while : 'a t -> f:('a -> bool) -> 'a t
val take_whilei : 'a t -> f:(int -> 'a -> bool) -> 'a t

val drop : int -> 'a t -> unit
val drop_while : 'a t -> f:('a -> bool) -> unit
val drop_whilei : 'a t -> f:(int -> 'a -> bool) -> unit

  (** Similar to [drop] but returns a fresh stream obtained after
      discarding the [n] first elements. Being a fresh stream, the
      count of the returned stream starts from 0 *)
val skip : int -> 'a t -> 'a t
val skip_while : 'a t -> f:('a -> bool) -> 'a t
val skip_whilei : 'a t -> f:(int -> 'a -> bool) -> 'a t

val span : 'a t -> f:('a -> bool) -> 'a t * 'a t
  (** [span test e] produces two streams [(hd, tl)], such that
      [hd] is the same as [take_while test e] and [tl] is the same
      as [skip_while test e]. *)

val group : 'a t -> f:('a -> 'b) -> 'a t t

val group_by : 'a t -> eq:('a -> 'a -> bool) -> 'a t t




val map : 'a t -> f:('a -> 'b) -> 'b t
val mapi : 'a t -> f:(int -> 'a -> 'b) -> 'b t
val filter : 'a t -> f:('a -> bool) -> 'a t
val filter_map : 'a t -> f:('a -> 'b option) -> 'b t
val append : 'a t -> 'a t -> 'a t
val concat : 'a t t -> 'a t

val combine : 'a t * 'b t -> ('a * 'b) t
  (** [combine] transforms a pair of streams into a stream of pairs of
      corresponding elements. If one stream is short, excess elements
      of the longer stream are ignored. *)

val uncombine : ('a * 'b) t -> 'a t * 'b t
  (** [uncombine] is the opposite of [combine] *)

val merge : 'a t -> 'a t -> cmp:('a -> 'a -> int) -> 'a t
  (** [merge test (a, b)] merge the elements from [a] and [b] into a
      single stream. At each step, [test] is applied to the first
      element of [a] and the first element of [b] to determine which
      should get first into the resulting stream. If [a] or [b]
      runs out of elements, the process will append all elements of
      the other stream to the result.  *)

val partition : 'a t -> f:('a -> bool) -> 'a t * 'a t
  (** [partition e ~f] splits [e] into two streams, where the first
      stream have all the elements satisfying [f], the second stream
      is opposite. The order of elements in the source stream is
      preserved. *)

val uniq : 'a t -> 'a t
  (** [uniq e] returns a duplicate of [e] with repeated values
      omitted. (similar to unix's [uniq] command) *)

val range : ?until:int -> int -> int t
  (** [range p until:q] creates a stream of integers [[p, p+1, ..., q]].
      If [until] is omitted, the enumeration is not bounded. Behaviour is
      not-specified once [max_int] has been reached.*)

val lines_of_chars : char t -> string t
val lines_of_channel : in_channel -> string Stream.t

val to_list : 'a t -> 'a list
val result_to_exn :
  ('output, 'error) Result.t t ->
  error_to_exn:('error -> exn) ->
  'output t
  (** Convert exception-less stream to exception-ful
      stream. Resulting stream raises exception at first error
      seen. *)

val empty : unit -> 'a t
val init : int -> f:(int -> 'a) -> 'a t
val singleton : 'a -> 'a t
val loop : 'a -> f:(int -> 'a -> 'a option) -> 'a t
val repeat : ?times:int -> 'a -> 'a t
val cycle : ?times:int -> 'a t -> 'a t

module Infix : sig
  val ( -- ) : int -> int -> int t
    (** As [range], without the label.

        [5 -- 10] is the enumeration 5,6,7,8,9,10.
        [10 -- 5] is the empty enumeration*)

  val ( --^ ) : int -> int -> int t
    (** As [(--)] but without the right endpoint

        [5 --^ 10] is the enumeration 5,6,7,8,9.
    *)

  val ( --. ) : (float * float) -> float -> float t
    (** [(a, step) --. b)] creates a float enumeration from [a] to [b] with an
        increment of [step] between elements.

        [(5.0, 1.0) --. 10.0] is the enumeration 5.0,6.0,7.0,8.0,9.0,10.0.
        [(10.0, -1.0) --. 5.0] is the enumeration 10.0,9.0,8.0,7.0,6.0,5.0.
        [(10.0, 1.0) --. 1.0] is the empty enumeration. *)

  val ( --- ) : int -> int -> int t
    (** As [--], but accepts enumerations in reverse order.

        [5 --- 10] is the enumeration 5,6,7,8,9,10.
        [10 --- 5] is the enumeration 10,9,8,7,6,5.*)

  val ( /@ ) : 'a t -> ('a -> 'b) -> 'b t
    (** [s /@ f] is equivalent to [map f s] *)

  val ( // ) : 'a t -> ('a -> bool) -> 'a t
    (** [s // f] is equivalent to [filter f s] *)

  val ( //@ ) : 'a t -> ('a -> 'b option) -> 'b t
  (** [s //@ f] is equivalent to [filter_map f s] *)
end
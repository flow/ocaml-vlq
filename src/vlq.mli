(**
 * Copyright (c) 2018-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(** VLQ encoding and decoding.

   This module implements VLQ encoding and decoding with support for custom
   shift and also embeds by default a Base 64 construction of the module.
   Check {{:https://en.wikipedia.org/wiki/Variable-length_quantity} this article}
*)

module type Config = sig
  val shift : int
    (** VLQ base shift to compute VLQ base *)

  val char_of_int : int -> char
    (** Takes an int and returns the corresponding char for it,
        which will be then used to build the encoded value. *)

  val int_of_char : char -> int
    (** Takes a char and returns the corresponding int for it,
        which will be then used to build the decoded value. *)
end

exception Unexpected_eof
  (** Happens when decoding a VLQ value with a continuation sign + eof *)

exception Char_of_int_failure of int
  (** Happens when the provided int cannot be converted to a char *)

exception Int_of_char_failure of char
  (** Happens when the provided char cannot be converted to an int *)

module type S = sig
  val encode: Buffer.t -> int -> unit
  val decode: char Stream.t -> int
end

module Base64 : S
  (** A single base 64 digit can contain 6 bits of data. For the base 64
      variable length quantities we use in the source map spec, the first
      bit is the sign, the next four bits are the actual value, and the 6th
      bit is the continuation bit. The continuation bit tells us whether
      there are more digits in this value following this digit.

      {v
        Continuation
        |    Sign
        |    |
        V    V
        101011
       v}
  *)

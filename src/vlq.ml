(**
 * Copyright (c) 2018-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module type Config = sig
  val shift : int
  val char_of_int : int -> char
  val int_of_char : char -> int
end

module type S = sig
  val encode : int -> string
  val decode : string -> int
end

exception Unexpected_eof
exception Char_of_int_failure of int
exception Int_of_char_failure of char

module Make (C: Config) = struct
  let vlq_base = 1 lsl C.shift
  let vlq_base_mask = vlq_base - 1
  let vlq_continuation_bit = vlq_base

  (** Converts from a two-complement value to a value where the sign bit is
      placed in the least significant bit.  For example, as decimals:
        1 becomes 2 (10 binary), -1 becomes 3 (11 binary)
        2 becomes 4 (100 binary), -2 becomes 5 (101 binary) *)
  let vlq_signed_of_int value =
      match value < 0 with
      | true  -> ((-value) lsl 1) + 1
      | false -> value lsl 1

  let encode value =
    let vlq = vlq_signed_of_int value in
    let rec loop vlq encoded =
      let digit = vlq land vlq_base_mask in
      let vlq = vlq lsr C.shift in
      match vlq = 0 with
      | true  -> encoded ^ Char.escaped (C.char_of_int digit)
      | false ->
        loop vlq (encoded ^ Char.escaped
          (C.char_of_int (digit lor vlq_continuation_bit))) in
    loop vlq ""

  let decode value =
    let stream = Stream.of_string value in
    let rec loop shift decoded =
      let chr =
        try Stream.next stream
        with Stream.Failure -> raise Unexpected_eof in
      let digit = C.int_of_char chr in
      let decoded = decoded + (digit land vlq_base_mask) lsl shift in
      match digit land vlq_continuation_bit with
      | 0 -> decoded
      | _ -> (* Continuation found *)
        loop (shift + C.shift) decoded in
    let decoded = loop 0 0 in
    let abs = decoded / 2 in
    match decoded land 1 with
    | 0 -> abs
    | _ -> -(abs)
end

module Base64 = Make(struct
  let shift = 5
  let base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

  (* Convert a number between 0 and 63 to a base64 char *)
  let char_of_int digit =
    match digit >= 0, digit < String.length base64 with
    | true, true -> base64.[digit]
    | _ -> raise (Char_of_int_failure digit)

  let int_of_char chr =
    match String.index_opt base64 chr with
    | Some index -> index
    | None -> raise (Int_of_char_failure chr)
end)

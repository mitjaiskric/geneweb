(* camlp4r pa_extend.cmo ../src/pa_lock.cmo *)
(* $Id: ged2gwb.ml,v 4.11 2001-08-22 14:52:08 ddr Exp $ *)
(* Copyright (c) 2001 INRIA *)

open Def;
open Gutil;

value log_oc = ref stdout;

type record =
  { rlab : string;
    rval : string;
    rcont : string;
    rsons : list record;
    rpos : int;
    rused : mutable bool }
;

type choice3 'a 'b 'c 'd =
  [ Left3 of 'a
  | Right3 of 'b and 'c and 'd ]
;
type month_number_dates =
  [ MonthDayDates
  | DayMonthDates
  | NoMonthNumberDates
  | MonthNumberHappened of string ]
;

type charset =
  [ Ansel
  | Ascii
  | Msdos
  | MacIntosh ]
;

value lowercase_first_names = ref False;
value lowercase_surnames = ref False;
value extract_first_names = ref False;
value extract_public_names = ref True;
value charset_option = ref None;
value charset = ref Ascii;
value alive_years = ref 80;
value dead_years = ref 120;
value try_negative_dates = ref False;
value no_negative_dates = ref False;
value month_number_dates = ref NoMonthNumberDates;
value no_public_if_titles = ref False;
value first_names_brackets = ref None;
value untreated_in_notes = ref False;
value force = ref False;
value default_source = ref "";

(* Reading input *)

value line_cnt = ref 1;
value in_file = ref "";

value print_location pos =
  Printf.fprintf log_oc.val "File \"%s\", line %d:\n" in_file.val pos
;

value rec skip_eol =
  parser
  [ [: `'\010' | '\013'; _ = skip_eol :] -> ()
  | [: :] -> () ]
;

value rec get_to_eoln len =
  parser
  [ [: `'\010' | '\013'; _ = skip_eol :] -> Buff.get len
  | [: `'\t'; s :] -> get_to_eoln (Buff.store len ' ') s
  | [: `c; s :] -> get_to_eoln (Buff.store len c) s
  | [: :] -> Buff.get len ]
;

value rec skip_to_eoln =
  parser
  [ [: `'\010' | '\013'; _ = skip_eol :] -> ()
  | [: `_; s :] -> skip_to_eoln s
  | [: :] -> () ]
;

value eol_chars = ['\010'; '\013'];
value rec get_ident len =
  parser
  [ [: `' ' | '\t' :] -> Buff.get len
  | [: `c when not (List.mem c eol_chars); s :] ->
      get_ident (Buff.store len c) s
  | [: :] -> Buff.get len ]
;

value skip_space =
  parser
  [ [: `' ' | '\t' :] -> ()
  | [: :] -> () ]
;

value rec line_start num =
  parser
  [ [: `' '; s :] -> line_start num s
  | [: `x when x = num :] -> () ]
;

value ascii_of_msdos s =
  let s' = String.create (String.length s) in
  do {
    for i = 0 to String.length s - 1 do {
      let cc =
        match Char.code s.[i] with
        [ 0o200 -> 0o307
        | 0o201 -> 0o374
        | 0o202 -> 0o351
        | 0o203 -> 0o342
        | 0o204 -> 0o344
        | 0o205 -> 0o340
        | 0o206 -> 0o345
        | 0o207 -> 0o347
        | 0o210 -> 0o352
        | 0o211 -> 0o353
        | 0o212 -> 0o350
        | 0o213 -> 0o357
        | 0o214 -> 0o356
        | 0o215 -> 0o354
        | 0o216 -> 0o304
        | 0o217 -> 0o305
        | 0o220 -> 0o311
        | 0o221 -> 0o346
        | 0o222 -> 0o306
        | 0o223 -> 0o364
        | 0o224 -> 0o366
        | 0o225 -> 0o362
        | 0o226 -> 0o373
        | 0o227 -> 0o371
        | 0o230 -> 0o377
        | 0o231 -> 0o326
        | 0o232 -> 0o334
        | 0o233 -> 0o242
        | 0o234 -> 0o243
        | 0o235 -> 0o245
        | 0o240 -> 0o341
        | 0o241 -> 0o355
        | 0o242 -> 0o363
        | 0o243 -> 0o372
        | 0o244 -> 0o361
        | 0o245 -> 0o321
        | 0o246 -> 0o252
        | 0o247 -> 0o272
        | 0o250 -> 0o277
        | 0o252 -> 0o254
        | 0o253 -> 0o275
        | 0o254 -> 0o274
        | 0o255 -> 0o241
        | 0o256 -> 0o253
        | 0o257 -> 0o273
        | 0o346 -> 0o265
        | 0o361 -> 0o261
        | 0o366 -> 0o367
        | 0o370 -> 0o260
        | 0o372 -> 0o267
        | 0o375 -> 0o262
        | c -> c ]
      in
      s'.[i] := Char.chr cc
    };
    s'
  }
;

value ascii_of_macintosh s =
  let s' = String.create (String.length s) in
  do {
    for i = 0 to String.length s - 1 do {
      let cc =
        match Char.code s.[i] with
        [ 0o200 -> 0o304
        | 0o201 -> 0o305
        | 0o202 -> 0o307
        | 0o203 -> 0o311
        | 0o204 -> 0o321
        | 0o205 -> 0o326
        | 0o206 -> 0o334
        | 0o207 -> 0o341
        | 0o210 -> 0o340
        | 0o211 -> 0o342
        | 0o212 -> 0o344
        | 0o213 -> 0o343
        | 0o214 -> 0o345
        | 0o215 -> 0o347
        | 0o216 -> 0o351
        | 0o217 -> 0o350
        | 0o220 -> 0o352
        | 0o221 -> 0o353
        | 0o222 -> 0o355
        | 0o223 -> 0o354
        | 0o224 -> 0o356
        | 0o225 -> 0o357
        | 0o226 -> 0o361
        | 0o227 -> 0o363
        | 0o230 -> 0o362
        | 0o231 -> 0o364
        | 0o232 -> 0o366
        | 0o233 -> 0o365
        | 0o234 -> 0o372
        | 0o235 -> 0o371
        | 0o236 -> 0o373
        | 0o237 -> 0o374
        | 0o241 -> 0o260
        | 0o244 -> 0o247
        | 0o245 -> 0o267
        | 0o246 -> 0o266
        | 0o247 -> 0o337
        | 0o250 -> 0o256
        | 0o256 -> 0o306
        | 0o257 -> 0o330
        | 0o264 -> 0o245
        | 0o273 -> 0o252
        | 0o274 -> 0o272
        | 0o276 -> 0o346
        | 0o277 -> 0o370
        | 0o300 -> 0o277
        | 0o301 -> 0o241
        | 0o302 -> 0o254
        | 0o307 -> 0o253
        | 0o310 -> 0o273
        | 0o312 -> 0o040
        | 0o313 -> 0o300
        | 0o314 -> 0o303
        | 0o315 -> 0o325
        | 0o320 -> 0o255
        | 0o326 -> 0o367
        | 0o330 -> 0o377
        | 0o345 -> 0o302
        | 0o346 -> 0o312
        | 0o347 -> 0o301
        | 0o350 -> 0o313
        | 0o351 -> 0o310
        | 0o352 -> 0o315
        | 0o353 -> 0o316
        | 0o354 -> 0o317
        | 0o355 -> 0o314
        | 0o356 -> 0o323
        | 0o357 -> 0o324
        | 0o361 -> 0o322
        | 0o362 -> 0o332
        | 0o363 -> 0o333
        | 0o364 -> 0o331
        | c -> c ]
      in
      s'.[i] := Char.chr cc
    };
    s'
  }
;

value ascii_of_string s =
  match charset.val with
  [ Ansel -> Ansel.to_iso_8859_1 s
  | Ascii -> s
  | Msdos -> ascii_of_msdos s
  | MacIntosh -> ascii_of_macintosh s ]
;

value rec get_lev n =
  parser
    [: _ = line_start n; _ = skip_space; r1 = get_ident 0; strm :] ->
      let (rlab, rval, rcont, l) =
        if String.length r1 > 0 && r1.[0] = '@' then parse_address n r1 strm
        else parse_text n r1 strm
      in
      {rlab = rlab; rval = ascii_of_string rval;
       rcont = ascii_of_string rcont; rsons = List.rev l; rpos = line_cnt.val;
       rused = False}
and parse_address n r1 =
  parser
    [: r2 = get_ident 0; r3 = get_to_eoln 0 ? "get to eoln";
       l = get_lev_list [] (Char.chr (Char.code n + 1)) ? "get lev list" :] ->
      (r2, r1, r3, l)
and parse_text n r1 =
  parser
    [: r2 = get_to_eoln 0;
       l = get_lev_list [] (Char.chr (Char.code n + 1)) ? "get lev list" :] ->
      (r1, r2, "", l)
and get_lev_list l n =
  parser
  [ [: x = get_lev n; s :] -> get_lev_list [x :: l] n s
  | [: :] -> l ]
;

(* Error *)

value bad_dates_warned = ref False;

value print_bad_date pos d =
  if bad_dates_warned.val then ()
  else do {
    bad_dates_warned.val := True;
    print_location pos;
    Printf.fprintf log_oc.val "Can't decode date %s\n" d;
    flush log_oc.val
  }
;

value check_month m =
  if m < 1 || m > 12 then do {
    Printf.fprintf log_oc.val "Bad (numbered) month in date: %d\n" m;
    flush log_oc.val
  }
  else ()
;

value warning_month_number_dates () =
  match month_number_dates.val with
  [ MonthNumberHappened s ->
      do {
        Printf.fprintf log_oc.val "
  Warning: the file holds dates with numbered months (like: 12/05/1912).

  GEDCOM standard *requires* that months in dates be identifiers. The
  correct form for this example would be 12 MAY 1912 or 5 DEC 1912.

  Consider restarting with option \"-dates_dm\" or \"-dates_md\".
  Use option -help to see what they do.

  (example found in gedcom: \"%s\")
"
          s;
        flush log_oc.val
      }
  | _ -> () ]
;

(* Decoding fields *)

value rec skip_spaces =
  parser
  [ [: `' '; s :] -> skip_spaces s
  | [: :] -> () ]
;

value rec ident_slash len =
  parser
  [ [: `'/' :] -> Buff.get len
  | [: `'\t'; a = ident_slash (Buff.store len ' ') :] -> a
  | [: `c; a = ident_slash (Buff.store len c) :] -> a
  | [: :] -> Buff.get len ]
;

value strip c str =
  let start =
    loop 0 where rec loop i =
      if i == String.length str then i
      else if str.[i] == c then loop (i + 1)
      else i
  in
  let stop =
    loop (String.length str - 1) where rec loop i =
      if i == -1 then i + 1 else if str.[i] == c then loop (i - 1) else i + 1
  in
  if start == 0 && stop == String.length str then str
  else if start >= stop then ""
  else String.sub str start (stop - start)
;

value strip_spaces = strip ' ';
value strip_newlines = strip '\n';

value less_greater_escaped s =
  let rec need_code i =
    if i < String.length s then
      match s.[i] with
      [ '<' | '>' -> True
      | x -> need_code (succ i) ]
    else False
  in
  let rec compute_len i i1 =
    if i < String.length s then
      let i1 =
        match s.[i] with
        [ '<' | '>' -> i1 + 4
        | _ -> succ i1 ]
      in
      compute_len (succ i) i1
    else i1
  in
  let rec copy_code_in s1 i i1 =
    if i < String.length s then
      let i1 =
        match s.[i] with
        [ '<' -> do { String.blit "&lt;" 0 s1 i1 4; i1 + 4 }
        | '>' -> do { String.blit "&gt;" 0 s1 i1 4; i1 + 4 }
        | c -> do { s1.[i1] := c; succ i1 } ]
      in
      copy_code_in s1 (succ i) i1
    else s1
  in
  if need_code 0 then
    let len = compute_len 0 0 in
    copy_code_in (String.create len) 0 0
  else s
;

value parse_name =
  parser
    [: _ = skip_spaces;
       invert =
         parser
         [ [: `'/' :] -> True
         | [: :] -> False ];
       f = ident_slash 0; _ = skip_spaces; s = ident_slash 0 :] ->
      let (f, s) = if invert then (s, f) else (f, s) in
      let f = strip_spaces f in
      let s = strip_spaces s in
      (if f = "" then "x" else f, if s = "" then "?" else s)
;

value rec find_field lab =
  fun
  [ [r :: rl] ->
      if r.rlab = lab then do { r.rused := True; Some r }
      else find_field lab rl
  | [] -> None ]
;

value rec find_all_fields lab =
  fun
  [ [r :: rl] ->
      if r.rlab = lab then do {
        r.rused := True; [r :: find_all_fields lab rl]
      }
      else find_all_fields lab rl
  | [] -> [] ]
;

value rec lexing_date =
  parser
  [ [: `('0'..'9' as c); n = number (Buff.store 0 c) :] -> ("INT", n)
  | [: `('A'..'Z' as c); i = ident (Buff.store 0 c) :] -> ("ID", i)
  | [: `'('; t = text 0 :] -> ("TEXT", t)
  | [: `'.' :] -> ("", ".")
  | [: `' ' | '\t' | '\013'; s :] -> lexing_date s
  | [: _ = Stream.empty :] -> ("EOI", "")
  | [: `x :] -> ("", String.make 1 x) ]
and number len =
  parser
  [ [: `('0'..'9' as c); a = number (Buff.store len c) :] -> a
  | [: :] -> Buff.get len ]
and ident len =
  parser
  [ [: `('A'..'Z' as c); a = ident (Buff.store len c) :] -> a
  | [: :] -> Buff.get len ]
and text len =
  parser
  [ [: `')' :] -> Buff.get len
  | [: `c; s :] -> text (Buff.store len c) s ]
;

value make_date_lexing s = Stream.from (fun _ -> Some (lexing_date s));

value tparse (p_con, p_prm) =
  ifdef CAMLP4_300 then None
  else if p_prm = "" then parser [: `(con, prm) when con = p_con :] -> prm
  else parser [: `(con, prm) when con = p_con && prm = p_prm :] -> prm
;

value using_token (p_con, p_prm) =
  match p_con with
  [ "" | "INT" | "ID" | "TEXT" | "EOI" -> ()
  | _ ->
      raise
        (Token.Error
           ("the constructor \"" ^ p_con ^
              "\" is not recognized by the lexer")) ]
;

value date_lexer =
  {Token.func s = (make_date_lexing s, fun _ -> (0, 0));
   Token.using = using_token; Token.removing _ = (); Token.tparse = tparse;
   Token.text _ = "<tok>"}
;

type range 'a =
  [ Begin of 'a
  | End of 'a
  | BeginEnd of 'a and 'a ]
; 

value date_g = Grammar.create date_lexer;
value date_value = Grammar.Entry.create date_g "date value";
value date_interval = Grammar.Entry.create date_g "date interval";

value roman_int_decode s =
  let decode_digit one five ten r =
    loop 0 where rec loop cnt i =
      if i >= String.length s then (10 * r + cnt, i)
      else if s.[i] = one then loop (cnt + 1) (i + 1)
      else if s.[i] = five then
        if cnt = 0 then loop 5 (i + 1) else (10 * r + 5 - cnt, i + 1)
      else if s.[i] = ten then (10 * r + 10 - cnt, i + 1)
      else (10 * r + cnt, i)
  in
  let (r, i) = decode_digit 'M' 'M' 'M' 0 0 in
  let (r, i) = decode_digit 'C' 'D' 'M' r i in
  let (r, i) = decode_digit 'X' 'L' 'C' r i in
  let (r, i) = decode_digit 'I' 'V' 'X' r i in
  if i = String.length s then r else raise Not_found
;

value is_roman_int x =
  try
    let _ = roman_int_decode x in
    True
  with
  [ Not_found -> False ]
;

value roman_int =
  let p = parser [: `("ID", x) when is_roman_int x :] -> roman_int_decode x in
  Grammar.Entry.of_parser date_g "roman int" p
;

value date_str = ref "";

value make_date n1 n2 n3 =
  let n3 =
    if no_negative_dates.val then
      match n3 with
      [ Some n3 -> Some (abs n3)
      | None -> None ]
    else n3
  in
  match (n1, n2, n3) with
  [ (Some d, Some m, Some y) ->
      let (d, m) =
        match m with
        [ Right m -> (d, m)
        | Left m ->
            match month_number_dates.val with
            [ DayMonthDates -> do { check_month m; (d, m) }
            | MonthDayDates -> do { check_month d; (m, d) }
            | _ ->
                if d >= 1 && m >= 1 && d <= 31 && m <= 31 then
                  if d > 13 && m <= 13 then (d, m)
                  else if m > 13 && d <= 13 then (m, d)
                  else if d > 13 && m > 13 then (0, 0)
                  else do {
                    month_number_dates.val :=
                      MonthNumberHappened date_str.val;
                    (0, 0)
                  }
                else (0, 0) ] ]
      in
      let (d, m) = if m < 1 || m > 13 then (0, 0) else (d, m) in
      {day = d; month = m; year = y; prec = Sure; delta = 0}
  | (None, Some m, Some y) ->
      let m =
        match m with
        [ Right m -> m
        | Left m -> m ]
      in
      {day = 0; month = m; year = y; prec = Sure; delta = 0}
  | (None, None, Some y) ->
      {day = 0; month = 0; year = y; prec = Sure; delta = 0}
  | (Some y, None, None) ->
      {day = 0; month = 0; year = y; prec = Sure; delta = 0}
  | _ -> raise (Stream.Error "bad date") ]
;

EXTEND
  GLOBAL: date_value date_interval;
  date_value:
    [ [ dr = date_range; EOI ->
          match dr with
          [ Begin (d, cal) -> Dgreg {(d) with prec = After} cal
          | End (d, cal) -> Dgreg {(d) with prec = Before} cal
          | BeginEnd (d1, cal) (d2, _) ->
              Dgreg {(d1) with prec = YearInt d2.year} cal ]
      | (d, cal) = date; EOI -> Dgreg d cal
      | s = TEXT -> Dtext s ] ]
  ;
  date_interval:
    [ [ ID "BEF"; dt = date_or_text; EOI -> End dt
      | ID "AFT"; dt = date_or_text; EOI -> Begin dt
      | ID "BET"; dt = date_or_text; ID "AND"; dt1 = date_or_text; EOI ->
          BeginEnd dt dt1
      | ID "TO"; dt = date_or_text; EOI -> End dt
      | ID "FROM"; dt = date_or_text; EOI -> Begin dt
      | ID "FROM"; dt = date_or_text; ID "TO"; dt1 = date_or_text; EOI ->
          BeginEnd dt dt1
      | dt = date_or_text; EOI -> Begin dt ] ]
  ;
  date_or_text:
    [ [ (d, cal) = date -> Dgreg d cal
      | s = TEXT -> Dtext s ] ]
  ;
  date_range:
    [ [ ID "BEF"; dt = date -> End dt
      | ID "AFT"; dt = date -> Begin dt
      | ID "BET"; dt = date; ID "AND"; dt1 = date -> BeginEnd dt dt1
      | ID "TO"; dt = date -> End dt
      | ID "FROM"; dt = date -> Begin dt
      | ID "FROM"; dt = date; ID "TO"; dt1 = date -> BeginEnd dt dt1 ] ]
  ;
  date:
    [ [ ID "ABT"; (d, cal) = date_calendar -> ({(d) with prec = About}, cal)
      | ID "ENV"; (d, cal) = date_calendar -> ({(d) with prec = About}, cal)
      | ID "EST"; (d, cal) = date_calendar -> ({(d) with prec = Maybe}, cal)
      | ID "AFT"; (d, cal) = date_calendar -> ({(d) with prec = Before}, cal)
      | ID "BEF"; (d, cal) = date_calendar -> ({(d) with prec = After}, cal)
      | (d, cal) = date_calendar -> (d, cal) ] ]
  ;
  date_calendar:
    [ [ "@"; "#"; ID "DGREGORIAN"; "@"; d = date_greg -> (d, Dgregorian)
      | "@"; "#"; ID "DJULIAN"; "@"; d = date_greg ->
          (Calendar.gregorian_of_julian d, Djulian)
      | "@"; "#"; ID "DFRENCH"; ID "R"; "@"; d = date_fren ->
          (Calendar.gregorian_of_french d, Dfrench)
      | "@"; "#"; ID "DHEBREW"; "@"; d = date_hebr ->
          (Calendar.gregorian_of_hebrew d, Dhebrew)
      | d = date_greg -> (d, Dgregorian) ] ]
  ;
  date_greg:
    [ [ LIST0 "."; n1 = OPT int; LIST0 [ "." | "/" ]; n2 = OPT gen_month;
        LIST0 [ "." | "/" ]; n3 = OPT int; LIST0 "." ->
          make_date n1 n2 n3 ] ]
  ;
  date_fren:
    [ [ LIST0 "."; n1 = int; (n2, n3) = date_fren_kont ->
          make_date (Some n1) n2 n3
      | LIST0 "."; n1 = year_fren -> make_date (Some n1) None None
      | LIST0 "."; (n2, n3) = date_fren_kont -> make_date None n2 n3 ] ]
  ;
  date_fren_kont:
    [ [ LIST0 [ "." | "/" ]; n2 = OPT gen_french; LIST0 [ "." | "/" ];
        n3 = OPT year_fren; LIST0 "." ->
          (n2, n3) ] ]
  ;
  date_hebr:
    [ [ LIST0 "."; n1 = OPT int; LIST0 [ "." | "/" ]; n2 = OPT gen_hebr;
        LIST0 [ "." | "/" ]; n3 = OPT int; LIST0 "." ->
          make_date n1 n2 n3 ] ]
  ;
  gen_month:
    [ [ i = int -> Left (abs i)
      | m = month -> Right m ] ]
  ;
  month:
    [ [ ID "JAN" -> 1
      | ID "FEB" -> 2
      | ID "MAR" -> 3
      | ID "APR" -> 4
      | ID "MAY" -> 5
      | ID "JUN" -> 6
      | ID "JUL" -> 7
      | ID "AUG" -> 8
      | ID "SEP" -> 9
      | ID "OCT" -> 10
      | ID "NOV" -> 11
      | ID "DEC" -> 12 ] ]
  ;
  gen_french:
    [ [ m = french -> Right m ] ]
  ;
  french:
    [ [ ID "VEND" -> 1
      | ID "BRUM" -> 2
      | ID "FRIM" -> 3
      | ID "NIVO" -> 4
      | ID "PLUV" -> 5
      | ID "VENT" -> 6
      | ID "GERM" -> 7
      | ID "FLOR" -> 8
      | ID "PRAI" -> 9
      | ID "MESS" -> 10
      | ID "THER" -> 11
      | ID "FRUC" -> 12
      | ID "COMP" -> 13 ] ]
  ;
  year_fren:
    [ [ i = int -> i
      | ID "AN"; i = roman_int -> i
      | i = roman_int -> i ] ]
  ;
  gen_hebr:
    [ [ m = hebr -> Right m ] ]
  ;
  hebr:
    [ [ ID "TSH" -> 1
      | ID "CSH" -> 2
      | ID "KSL" -> 3
      | ID "TVT" -> 4
      | ID "SHV" -> 5
      | ID "ADR" -> 6
      | ID "ADS" -> 7
      | ID "NSN" -> 8
      | ID "IYR" -> 9
      | ID "SVN" -> 10
      | ID "TMZ" -> 11
      | ID "AAV" -> 12
      | ID "ELL" -> 13 ] ]
  ;
  int:
    [ [ i = INT -> int_of_string i
      | "-"; i = INT -> - int_of_string i ] ]
  ;
END;

value date_of_field pos d =
  if d = "" then None
  else do {
    let s = Stream.of_string (String.uppercase d) in
    date_str.val := d;
    try Some (Grammar.Entry.parse date_value s) with
    [ Stdpp.Exc_located loc (Stream.Error _) -> Some (Dtext d) ]
  }
;

(* Creating base *)

type tab 'a = { arr : mutable array 'a; tlen : mutable int };

type gen =
  { g_per : tab (choice3 string person ascend union);
    g_fam : tab (choice3 string family couple descend);
    g_str : tab string;
    g_bnot : mutable string;
    g_ic : in_channel;
    g_not : Hashtbl.t string int;
    g_src : Hashtbl.t string int;
    g_hper : Hashtbl.t string Adef.iper;
    g_hfam : Hashtbl.t string Adef.ifam;
    g_hstr : Hashtbl.t string Adef.istr;
    g_hnam : Hashtbl.t string (ref int);
    g_adop : Hashtbl.t string (Adef.iper * string);
    g_godp : mutable list (Adef.iper * Adef.iper);
    g_witn : mutable list (Adef.ifam * Adef.iper) }
;

value assume_tab name tab none =
  if tab.tlen == Array.length tab.arr then do {
    let new_len = 2 * Array.length tab.arr + 1 in
    let new_arr = Array.create new_len none in
    Array.blit tab.arr 0 new_arr 0 (Array.length tab.arr);
    tab.arr := new_arr
  }
  else ()
;

value add_string gen s =
  try Hashtbl.find gen.g_hstr s with
  [ Not_found ->
      let i = gen.g_str.tlen in
      do {
        assume_tab "gen.g_str" gen.g_str "";
        gen.g_str.arr.(i) := s;
        gen.g_str.tlen := gen.g_str.tlen + 1;
        Hashtbl.add gen.g_hstr s (Adef.istr_of_int i);
        Adef.istr_of_int i
      } ]
;        

value extract_addr addr =
  if String.length addr > 0 && addr.[0] = '@' then
    try
      let r = String.index_from addr 1 '@' in
      String.sub addr 0 (r + 1)
    with
    [ Not_found -> addr ]
  else addr
;

value per_index gen lab =
  let lab = extract_addr lab in
  try Hashtbl.find gen.g_hper lab with
  [ Not_found ->
      let i = gen.g_per.tlen in
      do {
        assume_tab "gen.g_per" gen.g_per (Left3 "");
        gen.g_per.arr.(i) := Left3 lab;
        gen.g_per.tlen := gen.g_per.tlen + 1;
        Hashtbl.add gen.g_hper lab (Adef.iper_of_int i);
        Adef.iper_of_int i
      } ]
;

value fam_index gen lab =
  let lab = extract_addr lab in
  try Hashtbl.find gen.g_hfam lab with
  [ Not_found ->
      let i = gen.g_fam.tlen in
      do {
        assume_tab "gen.g_fam" gen.g_fam (Left3 "");
        gen.g_fam.arr.(i) := Left3 lab;
        gen.g_fam.tlen := gen.g_fam.tlen + 1;
        Hashtbl.add gen.g_hfam lab (Adef.ifam_of_int i);
        Adef.ifam_of_int i
      } ]
;

value unknown_per gen i =
  let empty = add_string gen "" in
  let what = add_string gen "?" in
  let p =
    {first_name = what; surname = what; occ = i; public_name = empty;
     image = empty; qualifiers = []; aliases = []; first_names_aliases = [];
     surnames_aliases = []; titles = []; rparents = []; related = [];
     occupation = empty; sex = Neuter; access = IfTitles;
     birth = Adef.codate_None; birth_place = empty; birth_src = empty;
     baptism = Adef.codate_None; baptism_place = empty; baptism_src = empty;
     death = DontKnowIfDead; death_place = empty; death_src = empty;
     burial = UnknownBurial; burial_place = empty; burial_src = empty;
     notes = empty; psources = empty; cle_index = Adef.iper_of_int i}
  and a = {parents = None; consang = Adef.fix (-1)}
  and u = {family = [| |]} in
  (p, a, u)
;

value phony_per gen sex =
  let i = gen.g_per.tlen in
  let (person, ascend, union) = unknown_per gen i in
  do {
    person.sex := sex;
    assume_tab "gen.g_per" gen.g_per (Left3 "");
    gen.g_per.tlen := gen.g_per.tlen + 1;
    gen.g_per.arr.(i) := Right3 person ascend union;
    Adef.iper_of_int i
  }
;

value unknown_fam gen i =
  let empty = add_string gen "" in
  let father = phony_per gen Male in
  let mother = phony_per gen Female in
  let f =
    {marriage = Adef.codate_None; marriage_place = empty;
     marriage_src = empty; witnesses = [| |]; relation = Married;
     divorce = NotDivorced; comment = empty; origin_file = empty;
     fsources = empty; fam_index = Adef.ifam_of_int i}
  and c = {father = father; mother = mother}
  and d = {children = [| |]} in
  (f, c, d)
;

value phony_fam gen =
  let i = gen.g_fam.tlen in
  let (fam, cpl, des) = unknown_fam gen i in
  do {
    assume_tab "gen.g_fam" gen.g_fam (Left3 "");
    gen.g_fam.tlen := gen.g_fam.tlen + 1;
    gen.g_fam.arr.(i) := Right3 fam cpl des;
    Adef.ifam_of_int i
  }
;

value this_year =
  let tm = Unix.localtime (Unix.time ()) in
  tm.Unix.tm_year + 1900
;

value infer_death birth =
  match birth with
  [ Some (Dgreg d _) ->
      let a = this_year - d.year in
      if a > dead_years.val then DeadDontKnowWhen
      else if a <= alive_years.val then NotDead
      else DontKnowIfDead
  | _ -> DontKnowIfDead ]
;

(*
value make_title gen (title, place) =
  {t_name = Tnone; t_ident = add_string gen title;
   t_place = add_string gen place; t_date_start = Adef.codate_None;
   t_date_end = Adef.codate_None; t_nth = 0}
;
*)

value string_ini_eq s1 i s2 =
  loop i 0 where rec loop i j =
    if j == String.length s2 then True
    else if i == String.length s1 then False
    else if s1.[i] == s2.[j] then loop (i + 1) (j + 1)
    else False
;

value particle s i =
  string_ini_eq s i "des " || string_ini_eq s i "DES " ||
  string_ini_eq s i "de " || string_ini_eq s i "DE " ||
  string_ini_eq s i "du " || string_ini_eq s i "DU " ||
  string_ini_eq s i "d'" || string_ini_eq s i "D'" ||
  string_ini_eq s i "y " || string_ini_eq s i "Y "
;

value lowercase_name s =
  let s = String.copy s in
  let rec loop uncap i =
    if i == String.length s then s
    else do {
      let c = s.[i] in
      let (c, uncap) =
        match c with
        [ 'a'..'z' | '�'..'�' ->
            (if uncap then c
             else Char.chr (Char.code c - Char.code 'a' + Char.code 'A'),
             True)
        | 'A'..'Z' | '�'..'�' ->
            (if not uncap then c
             else Char.chr (Char.code c - Char.code 'A' + Char.code 'a'),
             True)
        | c -> (c, particle s (i + 1)) ]
      in
      s.[i] := c;
      loop uncap (i + 1)
    }
  in
  loop (particle s 0) 0
;

value look_like_a_number s =
  loop 0 where rec loop i =
    if i == String.length s then True
    else
      match s.[i] with
      [ '0'..'9' -> loop (i + 1)
      | _ -> False ]
;

value is_a_name_char =
  fun
  [ 'A'..'Z' | 'a'..'z' | '�'..'�' | '�'..'�' | '�'..'�' | '0'..'9' | '-' |
    ''' ->
      True
  | _ -> False ]
;

value rec next_word_pos s i =
  if i == String.length s then i
  else if is_a_name_char s.[i] then i
  else next_word_pos s (i + 1)
;

value rec next_sep_pos s i =
  if i == String.length s then String.length s
  else if is_a_name_char s.[i] then next_sep_pos s (i + 1)
  else i
;

value public_name_word =
  ["Ier"; "I�re"; "der"; "den"; "die"; "el"; "le"; "la"; "the"]
;

value rec is_a_public_name s i =
  let i = next_word_pos s i in
  if i == String.length s then False
  else
    let j = next_sep_pos s i in
    if j > i then
      let w = String.sub s i (j - i) in
      if look_like_a_number w then True
      else if is_roman_int w then True
      else if List.mem w public_name_word then True
      else is_a_public_name s j
    else False
;

value lowercase_public_name s =
  loop 0 0 where rec loop len k =
    let i = next_word_pos s k in
    if i == String.length s then Buff.get len
    else
      let j = next_sep_pos s i in
      if j > i then
        let w = String.sub s i (j - i) in
        let w =
          if is_roman_int w || List.mem w public_name_word then w
          else String.capitalize (String.lowercase w)
        in
        let len =
          loop len k where rec loop len k =
            if k = i then len else loop (Buff.store len s.[k]) (k + 1)
        in
        loop (Buff.mstore len w) j
      else Buff.get len
;

value get_lev0 =
  parser
    [: _ = line_start '0'; _ = skip_space; r1 = get_ident 0; r2 = get_ident 0;
       r3 = get_to_eoln 0 ? "get to eoln";
       l = get_lev_list [] '1' ? "get lev list" :] ->
      let (rlab, rval) = if r2 = "" then (r1, "") else (r2, r1) in
      let rval = ascii_of_string rval in
      let rcont = ascii_of_string r3 in
      {rlab = rlab; rval = rval; rcont = rcont; rsons = List.rev l;
       rpos = line_cnt.val; rused = False}
;

value find_notes_record gen addr =
  match try Some (Hashtbl.find gen.g_not addr) with [ Not_found -> None ] with
  [ Some i ->
      do {
        seek_in gen.g_ic i;
        try Some (get_lev0 (Stream.of_channel gen.g_ic)) with
        [ Stream.Failure | Stream.Error _ -> None ]
      }
  | None -> None ]
;

value find_sources_record gen addr =
  match try Some (Hashtbl.find gen.g_src addr) with [ Not_found -> None ] with
  [ Some i ->
      do {
        seek_in gen.g_ic i;
        try Some (get_lev0 (Stream.of_channel gen.g_ic)) with
        [ Stream.Failure | Stream.Error _ -> None ]
      }
  | None -> None ]
;

value rec flatten_notes =
  fun
  [ [r :: rl] ->
      let n = flatten_notes rl in
      match r.rlab with
      [ "CONC" | "CONT" | "NOTE" ->
          [(r.rlab, r.rval) :: flatten_notes r.rsons @ n]
      | _ -> n ]
  | [] -> [] ]
;

value extract_notes gen rl =
  List.fold_right
    (fun r lines ->
       List.fold_right
         (fun r lines ->
            do {
              r.rused := True;
              if r.rlab = "NOTE" && r.rval <> "" && r.rval.[0] == '@' then
                let addr = extract_addr r.rval in
                match find_notes_record gen addr with
                [ Some r ->
                    let l = flatten_notes r.rsons in
                    [("NOTE", r.rcont) :: l @ lines]
                | None ->
                    do {
                      print_location r.rpos;
                      Printf.fprintf log_oc.val "Note %s not found\n" addr;
                      flush log_oc.val;
                      lines
                    } ]
              else [(r.rlab, r.rval) :: lines]
            })
         [r :: r.rsons] lines)
    rl []
;

value treat_notes gen rl =
  let lines = extract_notes gen rl in
  let notes =
    List.fold_left
      (fun s (lab, n) ->
         let spc = String.length n > 0 && n.[0] == ' ' in
         let end_spc =
           String.length n > 1 && n.[String.length n - 1] == ' '
         in
         let n = strip_spaces n in
         if s = "" then n ^ (if end_spc then " " else "")
         else if lab = "CONT" || lab = "NOTE" then
           s ^ "<br>\n" ^ n ^ (if end_spc then " " else "")
         else if n = "" then s
         else
           s ^ (if spc then "\n" else "") ^ n ^ (if end_spc then " " else ""))
      "" lines
  in
  strip_newlines notes
;

value source gen r =
  match find_field "SOUR" r.rsons with
  [ Some r ->
      if String.length r.rval > 0 && r.rval.[0] = '@' then
        match find_sources_record gen r.rval with
        [ Some v -> v.rcont
        | None ->
            do {
              print_location r.rpos;
              Printf.fprintf log_oc.val "Source %s not found\n" r.rval;
              flush log_oc.val;
              ""
            } ]
      else r.rval
  | _ -> "" ]
;

value string_empty = ref (Adef.istr_of_int 0);
value string_x = ref (Adef.istr_of_int 0);

value p_index_from s i c =
  if i >= String.length s then String.length s
  else try String.index_from s i c with [ Not_found -> String.length s ]
;

value strip_sub s beg len = strip_spaces (String.sub s beg len);

value decode_title s =
  let i1 = p_index_from s 0 ',' in
  let i2 = p_index_from s (i1 + 1) ',' in
  let title = strip_sub s 0 i1 in
  let (place, nth) =
    if i1 == String.length s then ("", 0)
    else if i2 == String.length s then
      let s1 = strip_sub s (i1 + 1) (i2 - i1 - 1) in
      try ("", int_of_string s1) with [ Failure _ -> (s1, 0) ]
    else
      let s1 = strip_sub s (i1 + 1) (i2 - i1 - 1) in
      let s2 = strip_sub s (i2 + 1) (String.length s - i2 - 1) in
      try (s1, int_of_string s2) with
      [ Failure _ -> (strip_sub s i1 (String.length s - i1), 0) ]
  in
  (title, place, nth)
;

value list_of_string s =
  loop 0 0 [] where rec loop i len list =
    if i == String.length s then List.rev [Buff.get len :: list]
    else
      match s.[i] with
      [ ',' -> loop (i + 1) 0 [Buff.get len :: list]
      | c -> loop (i + 1) (Buff.store len c) list ]
;

value purge_list list =
  List.fold_right
    (fun s list ->
       match strip_spaces s with
       [ "" -> list
       | s -> [s :: list] ])
    list []
;

value decode_date_interval pos s =
  let strm = Stream.of_string s in
  try
    match Grammar.Entry.parse date_interval strm with
    [ BeginEnd d1 d2 -> (Some d1, Some d2)
    | Begin d -> (Some d, None)
    | End d -> (None, Some d) ]
  with
  [ Stdpp.Exc_located _ _ | Not_found ->
      do { print_bad_date pos s; (None, None) } ]
;

value treat_indi_title gen public_name r =
  let (title, place, nth) = decode_title r.rval in
  let (date_start, date_end) =
    match find_field "DATE" r.rsons with
    [ Some r -> decode_date_interval r.rpos r.rval
    | None -> (None, None) ]
  in
  let (name, title, place) =
    match find_field "NOTE" r.rsons with
    [ Some r ->
        if title = "" then (Tnone, strip_spaces r.rval, "")
        else if r.rval = public_name then (Tmain, title, place)
        else (Tname (add_string gen (strip_spaces r.rval)), title, place)
    | None -> (Tnone, title, place) ]
  in
  {t_name = name; t_ident = add_string gen title;
   t_place = add_string gen place;
   t_date_start = Adef.codate_of_od date_start;
   t_date_end = Adef.codate_of_od date_end; t_nth = nth}
;

value forward_adop gen ip lab which_parent =
  let which_parent =
    match which_parent with
    [ Some r -> r.rval
    | _ -> "" ]
  in
  let which_parent = if which_parent = "" then "BOTH" else which_parent in
  Hashtbl.add gen.g_adop lab (ip, which_parent)
;

value adop_parent gen ip r =
  let i = per_index gen r.rval in
  match gen.g_per.arr.(Adef.int_of_iper i) with
  [ Left3 _ -> None
  | Right3 p _ _ ->
      do {
        if List.memq ip p.related then () else p.related := [ip :: p.related];
        Some p.cle_index
      } ]
;

value set_adop_fam gen ip which_parent fath moth =
  match gen.g_per.arr.(Adef.int_of_iper ip) with
  [ Left3 _ -> ()
  | Right3 per _ _ ->
      let r_fath =
        match (which_parent, fath) with
        [ ("HUSB" | "BOTH", Some r) -> adop_parent gen ip r
        | _ -> None ]
      in
      let r_moth =
        match (which_parent, moth) with
        [ ("WIFE" | "BOTH", Some r) -> adop_parent gen ip r
        | _ -> None ]
      in
      let r =
        {r_type = Adoption; r_fath = r_fath; r_moth = r_moth;
         r_sources = add_string gen ""}
      in
      per.rparents := [r :: per.rparents] ]
;

value forward_godp gen ip rval =
  let ipp = per_index gen rval in
  do { gen.g_godp := [(ipp, ip) :: gen.g_godp]; ipp }
;

value forward_witn gen ip rval =
  let ifam = fam_index gen rval in
  do { gen.g_witn := [(ifam, ip) :: gen.g_witn]; ifam }
;

value glop = ref [];

value indi_lab =
  fun
  [ "ADOP" | "ASSO" | "BAPM" | "BIRT" | "BURI" | "CHR" | "CREM" | "DEAT" |
    "FAMC" | "FAMS" | "NAME" | "NOTE" | "OBJE" | "OCCU" | "SEX" | "SOUR" |
    "TITL" ->
      True
  | c ->
      do {
        if List.mem c glop.val then ()
        else do {
          glop.val := [c :: glop.val];
          Printf.eprintf "untreated tag %s -> in notes\n" c;
          flush stderr
        };
        False
      } ]
;

value html_text_of_tags rl =
  let rec tot len lev r =
    let len = Buff.mstore len (string_of_int lev) in
    let len = Buff.store len ' ' in
    let len = Buff.mstore len r.rlab in
    let len =
      if r.rval = "" then len else Buff.mstore (Buff.store len ' ') r.rval
    in
    let len =
      if r.rcont = "" then len else Buff.mstore (Buff.store len ' ') r.rcont
    in
    totl len (lev + 1) r.rsons
  and totl len lev rl =
    List.fold_left
      (fun len r ->
         let len = Buff.store len '\n' in
         tot len lev r)
      len rl
  in
  let len = 0 in
  let len = Buff.mstore len "<pre>\n" in
  let len = Buff.mstore len "-- GEDCOM --" in
  let len = totl len 1 rl in
  let len = Buff.mstore len "\n</pre>" in
  Buff.get len
;

value add_indi gen r =
  let i = per_index gen r.rval in
  let name_sons = find_field "NAME" r.rsons in
  let givn =
    match name_sons with
    [ Some n ->
        match find_field "GIVN" n.rsons with
        [ Some r -> r.rval
        | None -> "" ]
    | None -> "" ]
  in
  let (first_name, surname, occ, public_name, first_names_aliases) =
    match name_sons with
    [ Some n ->
        let (f, s) = parse_name (Stream.of_string n.rval) in
        let pn = if givn = f then "" else givn in
        let fal = [] in
        let (f, fal) =
          match first_names_brackets.val with
          [ Some (' ', eb) ->
              try
                let j = String.index f eb in
                let i =
                  try String.rindex_from f (j - 1) ' ' with
                  [ Not_found -> -1 ]
                in
                let fn = String.sub f (i + 1) (j - i - 1) in
                let fa =
                  String.sub f 0 j ^
                    String.sub f (j + 1) (String.length f - j - 1)
                in
                if fn = fa then (fn, fal) else (fn, [fa :: fal])
              with
              [ Not_found -> (f, fal) ]
          | Some (bb, eb) ->
              try
                let i = String.index f bb in
                let j =
                  if i + 2 == String.length f then raise Not_found
                  else String.index_from f (i + 2) eb
                in
                let fn = String.sub f (i + 1) (j - i - 1) in
                let fa =
                  String.sub f 0 i ^ fn ^
                    String.sub f (j + 1) (String.length f - j - 1)
                in
                if fn = fa then (fn, fal) else (fn, [fa :: fal])
              with
              [ Not_found -> (f, fal) ]
          | None -> (f, fal) ]
        in
        let (f, pn, fal) =
          if extract_public_names.val || extract_first_names.val then
            let i = next_word_pos f 0 in
            let j = next_sep_pos f i in
            if j == String.length f then (f, pn, fal)
            else
              let fn = String.sub f i (j - i) in
              if pn = "" && extract_public_names.val then
                if is_a_public_name f j then (fn, f, fal)
                else if extract_first_names.val then (fn, "", [f :: fal])
                else (f, "", fal)
              else (fn, pn, [f :: fal])
          else (f, pn, fal)
        in
        let f = if lowercase_first_names.val then lowercase_name f else f in
        let fal =
          if lowercase_first_names.val then List.map lowercase_name fal
          else fal
        in
        let pn = if lowercase_name pn = f then "" else pn in
        let pn =
          if lowercase_first_names.val then lowercase_public_name pn else pn
        in
        let fal =
          List.fold_right (fun fa fal -> if fa = pn then fal else [fa :: fal])
            fal []
        in
        let s = if lowercase_surnames.val then lowercase_name s else s in
        let r =
          let key = Name.strip_lower (nominative f ^ " " ^ nominative s) in
          try Hashtbl.find gen.g_hnam key with
          [ Not_found ->
              let r = ref (-1) in
              do { Hashtbl.add gen.g_hnam key r; r } ]
        in
        do { incr r; (f, s, r.val, pn, fal) }
    | None -> ("?", "?", Adef.int_of_iper i, givn, []) ]
  in
  let qualifier =
    match name_sons with
    [ Some n ->
        match find_field "NICK" n.rsons with
        [ Some r -> r.rval
        | None -> "" ]
    | None -> "" ]
  in
  let surname_aliases =
    match name_sons with
    [ Some n ->
        match find_field "SURN" n.rsons with
        [ Some r ->
            let list = purge_list (list_of_string r.rval) in
            List.fold_right
              (fun x list ->
                 let x =
                   if lowercase_surnames.val then lowercase_name x else x
                 in
                 if x <> surname then [x :: list] else list)
              list []
        | _ -> [] ]
    | None -> [] ]
  in
  let aliases =
    match find_all_fields "NAME" r.rsons with
    [ [_ :: l] -> List.map (fun r -> r.rval) l
    | _ -> [] ]
  in
  let sex =
    match find_field "SEX" r.rsons with
    [ Some {rval = "M"} -> Male
    | Some {rval = "F"} -> Female
    | _ -> Neuter ]
  in
  let image =
    match find_field "OBJE" r.rsons with
    [ Some r ->
        match find_field "FILE" r.rsons with
        [ Some r -> r.rval
        | None -> "" ]
    | None -> "" ]
  in
  let parents =
    match find_field "FAMC" r.rsons with
    [ Some r -> Some (fam_index gen r.rval)
    | None -> None ]
  in
  let occupation =
    match find_all_fields "OCCU" r.rsons with
    [ [r :: rl] -> List.fold_left (fun s r -> s ^ ", " ^ r.rval) r.rval rl
    | [] -> "" ]
  in
  let notes =
    match find_all_fields "NOTE" r.rsons with
    [ [] -> ""
    | rl -> treat_notes gen rl ]
  in
  let titles =
    List.map (treat_indi_title gen public_name)
      (find_all_fields "TITL" r.rsons)
  in
  let family =
    let rl = find_all_fields "FAMS" r.rsons in
    let rvl =
      List.fold_right
        (fun r rvl -> if List.mem r.rval rvl then rvl else [r.rval :: rvl]) rl
        []
    in
    List.map (fun r -> fam_index gen r) rvl
  in
  let rparents =
    let rparents = [] in
    let rl = find_all_fields "ASSO" r.rsons in
    let rec find_rela n f =
      fun
      [ [] -> None
      | [r :: rl] ->
          match find_field "RELA" r.rsons with
          [ Some r1 ->
              let len = String.length n in
              if String.length r1.rval >= len &&
                 String.lowercase (String.sub r1.rval 0 len) = n
              then
                Some (f gen i r.rval)
              else find_rela n f rl
          | None -> find_rela n f rl ] ]
    in
    let godf = find_rela "godf" forward_godp r.rsons in
    let godm = find_rela "godm" forward_godp r.rsons in
    let witn = find_rela "witness" forward_witn r.rsons in
    if godf <> None || godm <> None then
      let r =
        {r_type = GodParent; r_fath = godf; r_moth = godm;
         r_sources = add_string gen ""}
      in
      [r :: rparents]
    else rparents
  in
  let (birth, birth_place, birth_src) =
    match find_field "BIRT" r.rsons with
    [ Some r ->
        let d =
          match find_field "DATE" r.rsons with
          [ Some r -> date_of_field r.rpos r.rval
          | _ -> None ]
        in
        let p =
          match find_field "PLAC" r.rsons with
          [ Some r -> r.rval
          | _ -> "" ]
        in
        (d, p, source gen r)
    | None -> (None, "", "") ]
  in
  let (bapt, bapt_place, bapt_src) =
    let ro =
      match find_field "BAPM" r.rsons with
      [ None -> find_field "CHR" r.rsons
      | x -> x ]
    in
    match ro with
    [ Some r ->
        let d =
          match find_field "DATE" r.rsons with
          [ Some r -> date_of_field r.rpos r.rval
          | _ -> None ]
        in
        let p =
          match find_field "PLAC" r.rsons with
          [ Some r -> r.rval
          | _ -> "" ]
        in
        (Adef.codate_of_od d, p, source gen r)
    | None -> (Adef.codate_None, "", "") ]
  in
  let (death, death_place, death_src) =
    match find_field "DEAT" r.rsons with
    [ Some r ->
        if r.rsons = [] then
          if r.rval = "Y" then (DeadDontKnowWhen, "", "")
          else (infer_death birth, "", "")
        else
          let d =
            match find_field "DATE" r.rsons with
            [ Some r ->
                match date_of_field r.rpos r.rval with
                [ Some d -> Death Unspecified (Adef.cdate_of_date d)
                | None -> DeadDontKnowWhen ]
            | _ -> DeadDontKnowWhen ]
          in
          let p =
            match find_field "PLAC" r.rsons with
            [ Some r -> r.rval
            | _ -> "" ]
          in
          (d, p, source gen r)
    | None -> (infer_death birth, "", "") ]
  in
  let (burial, burial_place, burial_src) =
    let (buri, buri_place, buri_src) =
      match find_field "BURI" r.rsons with
      [ Some r ->
          if r.rsons = [] then
            if r.rval = "Y" then (Buried Adef.codate_None, "", "")
            else (UnknownBurial, "", "")
          else
            let d =
              match find_field "DATE" r.rsons with
              [ Some r -> date_of_field r.rpos r.rval
              | _ -> None ]
            in
            let p =
              match find_field "PLAC" r.rsons with
              [ Some r -> r.rval
              | _ -> "" ]
            in
            (Buried (Adef.codate_of_od d), p, source gen r)
      | None -> (UnknownBurial, "", "") ]
    in
    let (crem, crem_place, crem_src) =
      match find_field "CREM" r.rsons with
      [ Some r ->
          if r.rsons = [] then
            if r.rval = "Y" then (Cremated Adef.codate_None, "", "")
            else (UnknownBurial, "", "")
          else
            let d =
              match find_field "DATE" r.rsons with
              [ Some r -> date_of_field r.rpos r.rval
              | _ -> None ]
            in
            let p =
              match find_field "PLAC" r.rsons with
              [ Some r -> r.rval
              | _ -> "" ]
            in
            (Cremated (Adef.codate_of_od d), p, source gen r)
      | None -> (UnknownBurial, "", "") ]
    in
    match (buri, crem) with
    [ (UnknownBurial, Cremated _) -> (crem, crem_place, crem_src)
    | _ -> (buri, buri_place, buri_src) ]
  in
  let birth = Adef.codate_of_od birth in
  let empty = add_string gen "" in
  let psources =
    let s = source gen r in
    if s = "" then default_source.val else s
  in
  let ext_notes =
    if untreated_in_notes.val then
      let rec build_remain_tags r_list =
        match r_list with
        [ [] -> []
        | [r :: rest] ->
            let rsons = build_remain_tags r.rsons in
            let rest = build_remain_tags rest in
            if r.rused = True && rsons = [] then rest
            else
              [{rlab = r.rlab; rval = r.rval; rcont = r.rcont; rsons = rsons;
                rpos = r.rpos; rused = r.rused} ::
               rest] ]
      in
      let remain_tags = build_remain_tags r.rsons in
      if remain_tags = [] then ""
      else
        let s = if notes = "" then "" else "\n" in
        s ^ html_text_of_tags (List.rev remain_tags)
    else ""
  in
  let person =
    {first_name = add_string gen first_name; surname = add_string gen surname;
     occ = occ; public_name = add_string gen public_name;
     image = add_string gen image;
     qualifiers = if qualifier <> "" then [add_string gen qualifier] else [];
     aliases = List.map (add_string gen) aliases;
     first_names_aliases = List.map (add_string gen) first_names_aliases;
     surnames_aliases = List.map (add_string gen) surname_aliases;
     titles = titles; rparents = rparents; related = [];
     occupation = add_string gen occupation; sex = sex;
     access =
       if no_public_if_titles.val && titles <> [] then Private else IfTitles;
     birth = birth; birth_place = add_string gen birth_place;
     birth_src = add_string gen birth_src; baptism = bapt;
     baptism_place = add_string gen bapt_place;
     baptism_src = add_string gen bapt_src; death = death;
     death_place = add_string gen death_place;
     death_src = add_string gen death_src; burial = burial;
     burial_place = add_string gen burial_place;
     burial_src = add_string gen burial_src;
     notes = add_string gen (notes ^ ext_notes);
     psources = add_string gen psources; cle_index = i}
  and ascend = {parents = parents; consang = Adef.fix (-1)}
  and union = {family = Array.of_list family} in
  do {
    gen.g_per.arr.(Adef.int_of_iper i) := Right3 person ascend union;
    match find_field "ADOP" r.rsons with
    [ Some r ->
        match find_field "FAMC" r.rsons with
        [ Some r -> forward_adop gen i r.rval (find_field "ADOP" r.rsons)
        | _ -> () ]
    | _ -> () ];
    r.rused := True
  }
;

value add_fam_norm gen r adop_list =
  let i = fam_index gen r.rval in
  let fath =
    match find_field "HUSB" r.rsons with
    [ Some r -> per_index gen r.rval
    | None -> phony_per gen Male ]
  in
  let moth =
    match find_field "WIFE" r.rsons with
    [ Some r -> per_index gen r.rval
    | None -> phony_per gen Female ]
  in
  do {
    match gen.g_per.arr.(Adef.int_of_iper fath) with
    [ Left3 lab -> ()
    | Right3 p _ u ->
        do {
          if not (List.memq i (Array.to_list u.family)) then
            u.family := Array.append u.family [| i |]
          else ();
          if p.sex = Neuter then p.sex := Male else ()
        } ];
    match gen.g_per.arr.(Adef.int_of_iper moth) with
    [ Left3 lab -> ()
    | Right3 p _ u ->
        do {
          if not (List.memq i (Array.to_list u.family)) then
            u.family := Array.append u.family [| i |]
          else ();
          if p.sex = Neuter then p.sex := Female else ()
        } ];
    let children =
      let rl = find_all_fields "CHIL" r.rsons in
      List.fold_right
        (fun r ipl ->
           let ip = per_index gen r.rval in
           if List.mem_assoc ip adop_list then
             match gen.g_per.arr.(Adef.int_of_iper ip) with
             [ Right3 _ ({parents = Some ifam} as a) _ ->
                 if ifam = i then do { a.parents := None; ipl }
                 else [ip :: ipl]
             | _ -> [ip :: ipl] ]
           else [ip :: ipl])
        rl []
    in
    let (relation, marr, marr_place, marr_src) =
      let (relation, sons) =
        match find_field "MARR" r.rsons with
        [ Some r -> (Married, Some r)
        | None ->
            match find_field "ENGA" r.rsons with
            [ Some r -> (Engaged, Some r)
            | None -> (Married, None) ] ]
      in
      match sons with
      [ Some r ->
          let (u, p) =
            match find_field "PLAC" r.rsons with
            [ Some r ->
                if String.uncapitalize r.rval = "unmarried" then
                  (NotMarried, "")
                else (relation, r.rval)
            | _ -> (relation, "") ]
          in
          let u =
            match find_field "TYPE" r.rsons with
            [ Some r ->
                if String.uncapitalize r.rval = "gay" then NoSexesCheck else u
            | None -> u ]
          in
          let d =
            if u = NotMarried then None
            else
              match find_field "DATE" r.rsons with
              [ Some r -> date_of_field r.rpos r.rval
              | _ -> None ]
          in
          (u, d, p, source gen r)
      | None -> (relation, None, "", "") ]
    in
    let div =
      match find_field "DIV" r.rsons with
      [ Some r ->
          match find_field "DATE" r.rsons with
          [ Some d ->
              Divorced (Adef.codate_of_od (date_of_field r.rpos r.rval))
          | _ ->
              match find_field "PLAC" r.rsons with
              [ Some _ -> Divorced Adef.codate_None
              | _ ->
                  if r.rval = "Y" then Divorced Adef.codate_None
                  else NotDivorced ] ]
      | None -> NotDivorced ]
    in
    let comment =
      match find_field "NOTE" r.rsons with
      [ Some r -> if r.rval <> "" && r.rval.[0] == '@' then "" else r.rval
      | None -> "" ]
    in
    let empty = add_string gen "" in
    let fsources =
      let s = source gen r in
      if s = "" then default_source.val else s
    in
    let fam =
      {marriage = Adef.codate_of_od marr;
       marriage_place = add_string gen marr_place;
       marriage_src = add_string gen marr_src; witnesses = [| |];
       relation = relation; divorce = div; comment = add_string gen comment;
       origin_file = empty; fsources = add_string gen fsources; fam_index = i}
    and cpl = {father = fath; mother = moth}
    and des = {children = Array.of_list children} in
    gen.g_fam.arr.(Adef.int_of_ifam i) := Right3 fam cpl des
  }
;

value add_fam gen r =
  let list = Hashtbl.find_all gen.g_adop r.rval in
  match list with
  [ [] -> add_fam_norm gen r []
  | list ->
      let husb = find_field "HUSB" r.rsons in
      let wife = find_field "WIFE" r.rsons in
      do {
        List.iter
          (fun (ip, which_parent) ->
             set_adop_fam gen ip which_parent husb wife)
          list;
        match find_field "CHIL" r.rsons with
        [ Some _ -> add_fam_norm gen r list
        | _ -> () ]
      } ]
;

value treat_header2 gen r =
  match charset_option.val with
  [ Some v -> charset.val := v
  | None ->
      match find_field "CHAR" r.rsons with
      [ Some r ->
          match r.rval with
          [ "ANSEL" -> charset.val := Ansel
          | "ASCII" | "IBMPC" -> charset.val := Ascii
          | "MACINTOSH" -> charset.val := MacIntosh
          | _ -> charset.val := Ascii ]
      | None -> () ] ]
;

value treat_header3 gen r =
  match find_all_fields "NOTE" r.rsons with
  [ [] -> ()
  | rl -> gen.g_bnot := treat_notes gen rl ]
;

value turn_around_genealogos_bug r =
  if String.length r.rlab > 0 && r.rlab.[0] = '@' then
    {(r) with rlab = r.rval; rval = r.rlab}
  else r
;

value make_gen2 gen r =
  let r = turn_around_genealogos_bug r in
  match r.rlab with
  [ "HEAD" -> treat_header2 gen r
  | "INDI" -> add_indi gen r
  | _ -> () ]
;

value make_gen3 gen r =
  let r = turn_around_genealogos_bug r in
  match r.rlab with
  [ "HEAD" -> treat_header3 gen r
  | "SUBM" -> ()
  | "INDI" -> ()
  | "FAM" -> add_fam gen r
  | "NOTE" -> ()
  | "SOUR" -> ()
  | "TRLR" -> do { Printf.eprintf "*** Trailer ok\n"; flush stderr }
  | s ->
      do {
        Printf.fprintf log_oc.val "Not implemented typ = %s\n" s;
        flush log_oc.val
      } ]
;

value rec sortable_by_date proj =
  fun
  [ [] -> True
  | [e :: el] ->
      match proj e with
      [ Some d -> sortable_by_date proj el
      | None -> False ] ]
;

value sort_by_date proj list =
  if sortable_by_date proj list then
    Sort.list
      (fun e1 e2 ->
         match (proj e1, proj e2) with
         [ (Some d1, Some d2) -> not (strictement_apres d1 d2)
         | _ -> False ])
      list
  else list
;

(* Printing check errors *)

value print_base_error base =
  fun
  [ AlreadyDefined p ->
      Printf.fprintf log_oc.val "%s\nis defined several times\n"
        (denomination base p)
  | OwnAncestor p ->
      Printf.fprintf log_oc.val "%s\nis his/her own ancestor\n"
        (denomination base p)
  | BadSexOfMarriedPerson p ->
      Printf.fprintf log_oc.val "%s\n  bad sex for a married person\n"
        (denomination base p) ]
;

value print_base_warning base =
  fun
  [ BirthAfterDeath p ->
      Printf.fprintf log_oc.val "%s\n  born after his/her death\n"
        (denomination base p)
  | IncoherentSex p ->
      Printf.printf "%s\n  sex not coherent with relations\n"
        (denomination base p)
  | ChangedOrderOfChildren ifam des _ ->
      let cpl = coi base ifam in
      Printf.fprintf log_oc.val "Changed order of children of %s and %s\n"
        (denomination base (poi base cpl.father))
        (denomination base (poi base cpl.mother))
  | ChildrenNotInOrder ifam des elder x ->
      let cpl = coi base ifam in
      do {
        Printf.fprintf log_oc.val
          "The following children of\n  %s\nand\n  %s\nare not in order:\n"
          (denomination base (poi base cpl.father))
          (denomination base (poi base cpl.mother));
        Printf.fprintf log_oc.val "- %s\n" (denomination base elder);
        Printf.fprintf log_oc.val "- %s\n" (denomination base x)
      }
  | DeadTooEarlyToBeFather father child ->
      do {
        Printf.fprintf log_oc.val "%s\n" (denomination base child);
        Printf.fprintf log_oc.val
          "  is born more than 2 years after the death of his/her father\n";
        Printf.fprintf log_oc.val "%s\n" (denomination base father)
      }
  | MarriageDateAfterDeath p ->
      do {
        Printf.fprintf log_oc.val "%s\n" (denomination base p);
        Printf.fprintf log_oc.val "married after his/her death\n"
      }
  | MarriageDateBeforeBirth p ->
      do {
        Printf.fprintf log_oc.val "%s\n" (denomination base p);
        Printf.fprintf log_oc.val "married before his/her birth\n"
      }
  | MotherDeadAfterChildBirth mother child ->
      Printf.fprintf log_oc.val
        "%s\n  is born after the death of his/her mother\n%s\n"
        (denomination base child) (denomination base mother)
  | ParentBornAfterChild parent child ->
      Printf.fprintf log_oc.val "%s born after his/her child %s\n"
        (denomination base parent) (denomination base child)
  | ParentTooYoung p a ->
      Printf.fprintf log_oc.val "%s was parent at age of %d\n"
        (denomination base p) (annee a)
  | TitleDatesError p t ->
      do {
        Printf.fprintf log_oc.val "%s\n" (denomination base p);
        Printf.fprintf log_oc.val "has incorrect title dates as:\n";
        Printf.fprintf log_oc.val "  %s %s\n" (sou base t.t_ident)
          (sou base t.t_place)
      }
  | UndefinedSex _ -> ()
  | YoungForMarriage p a ->
      Printf.fprintf log_oc.val "%s married at age %d\n" (denomination base p)
        (annee a) ]
;

value find_lev0 =
  parser bp
    [: _ = line_start '0'; _ = skip_space; r1 = get_ident 0; r2 = get_ident 0;
       _ = skip_to_eoln :] ->
      (bp, r1, r2)
;

value pass1 gen fname =
  let ic = open_in_bin fname in
  let strm = Stream.of_channel ic in
  let rec loop () =
    match try Some (find_lev0 strm) with [ Stream.Failure -> None ] with
    [ Some (bp, r1, r2) ->
        do {
          match r2 with
          [ "NOTE" -> Hashtbl.add gen.g_not r1 bp
          | "SOUR" -> Hashtbl.add gen.g_src r1 bp
          | _ -> () ];
          loop ()
        }
    | None ->
        match strm with parser
        [ [: `_ :] -> do { skip_to_eoln strm; loop () }
        | [: :] -> () ] ]
  in
  do { loop (); close_in ic }
;

value pass2 gen fname =
  let ic = open_in_bin fname in
  do {
    line_cnt.val := 0;
    let strm =
      Stream.from
        (fun i ->
           try
             let c = input_char ic in
             do { if c == '\n' then incr line_cnt else (); Some c }
           with
           [ End_of_file -> None ])
    in
    let rec loop () =
      match try Some (get_lev0 strm) with [ Stream.Failure -> None ] with
      [ Some r -> do { make_gen2 gen r; loop () }
      | None ->
          match strm with parser
          [ [: `'1'..'9' :] ->
              let _ : string = get_to_eoln 0 strm in
              loop ()
          | [: `_ :] ->
              let _ : string = get_to_eoln 0 strm in
              loop ()
          | [: :] -> () ] ]
    in
    loop ();
    List.iter
      (fun (ipp, ip) ->
         match gen.g_per.arr.(Adef.int_of_iper ipp) with
         [ Right3 p _ _ ->
             if List.memq ip p.related then ()
             else p.related := [ip :: p.related]
         | _ -> () ])
      gen.g_godp;
    close_in ic
  }
;

value pass3 gen fname =
  let ic = open_in_bin fname in
  do {
    line_cnt.val := 0;
    let strm =
      Stream.from
        (fun i ->
           try
             let c = input_char ic in
             do { if c == '\n' then incr line_cnt else (); Some c }
           with
           [ End_of_file -> None ])
    in
    let rec loop () =
      match try Some (get_lev0 strm) with [ Stream.Failure -> None ] with
      [ Some r -> do { make_gen3 gen r; loop () }
      | None ->
          match strm with parser
          [ [: `'1'..'9' :] ->
              let _ : string = get_to_eoln 0 strm in
              loop ()
          | [: `_ :] ->
              do {
                print_location line_cnt.val;
                Printf.fprintf log_oc.val "Strange input.\n";
                flush log_oc.val;
                let _ : string = get_to_eoln 0 strm in
                loop ()
              }
          | [: :] -> () ] ]
    in
    loop ();
    List.iter
      (fun (ifam, ip) ->
         match gen.g_fam.arr.(Adef.int_of_ifam ifam) with
         [ Right3 fam cpl _ ->
             match
               (gen.g_per.arr.(Adef.int_of_iper cpl.father),
                gen.g_per.arr.(Adef.int_of_iper ip))
             with
             [ (Right3 pfath _ _, Right3 p _ _) ->
                 do {
                   if List.memq cpl.father p.related then ()
                   else p.related := [cpl.father :: p.related];
                   fam.witnesses := Array.append fam.witnesses [| ip |]
                 }
             | _ -> () ]
         | _ -> () ])
      gen.g_witn;
    close_in ic
  }
;

value check_undefined gen =
  do {
    for i = 0 to gen.g_per.tlen - 1 do {
      match gen.g_per.arr.(i) with
      [ Right3 _ _ _ -> ()
      | Left3 lab ->
          let (p, a, u) = unknown_per gen i in
          do {
            Printf.fprintf log_oc.val "Warning: undefined person %s\n" lab;
            gen.g_per.arr.(i) := Right3 p a u
          } ]
    };
    for i = 0 to gen.g_fam.tlen - 1 do {
      match gen.g_fam.arr.(i) with
      [ Right3 _ _ _ -> ()
      | Left3 lab ->
          let (f, c, d) = unknown_fam gen i in
          do {
            Printf.fprintf log_oc.val "Warning: undefined family %s\n" lab;
            gen.g_fam.arr.(i) := Right3 f c d
          } ]
    }
  }
;

value add_parents_to_isolated gen =
  for i = 0 to gen.g_per.tlen - 1 do {
    match gen.g_per.arr.(i) with
    [ Right3 p a u ->
        if a.parents = None && Array.length u.family = 0 && p.rparents = [] &&
           p.related = []
        then
          let fn = gen.g_str.arr.(Adef.int_of_istr p.first_name) in
          let sn = gen.g_str.arr.(Adef.int_of_istr p.surname) in
          if fn = "?" && sn = "?" then ()
          else do {
            Printf.fprintf log_oc.val
              "Adding parents to isolated person: %s.%d %s\n" fn p.occ sn;
            let ifam = phony_fam gen in
            match gen.g_fam.arr.(Adef.int_of_ifam ifam) with
            [ Right3 fam cpl des ->
                do {
                  des.children := [| p.cle_index |];
                  a.parents := Some ifam;
                }
            | _ -> () ];
          }
        else ()
    | Left3 _ -> () ]
  }
;

value make_arrays in_file =
  let fname =
    if Filename.check_suffix in_file ".ged" then in_file
    else if Filename.check_suffix in_file ".GED" then in_file
    else in_file ^ ".ged"
  in
  let gen =
    {g_per = {arr = [| |]; tlen = 0}; g_fam = {arr = [| |]; tlen = 0};
     g_str = {arr = [| |]; tlen = 0}; g_bnot = ""; g_ic = open_in_bin fname;
     g_not = Hashtbl.create 3001; g_src = Hashtbl.create 3001;
     g_hper = Hashtbl.create 3001; g_hfam = Hashtbl.create 3001;
     g_hstr = Hashtbl.create 3001; g_hnam = Hashtbl.create 3001;
     g_adop = Hashtbl.create 3001; g_godp = []; g_witn = []}
  in
  do {
    string_empty.val := add_string gen "";
    string_x.val := add_string gen "x";
    Printf.eprintf "*** pass 1 (note)\n";
    flush stderr;
    pass1 gen fname;
    Printf.eprintf "*** pass 2 (indi)\n";
    flush stderr;
    pass2 gen fname;
    Printf.eprintf "*** pass 3 (fam)\n";
    flush stderr;
    pass3 gen fname;
    close_in gen.g_ic;
    check_undefined gen;
    add_parents_to_isolated gen;
    (gen.g_per, gen.g_fam, gen.g_str, gen.g_bnot)
  }
;

value make_subarrays (g_per, g_fam, g_str, g_bnot) =
  let persons =
    let pa = Array.create g_per.tlen (Obj.magic 0) in
    let aa = Array.create g_per.tlen (Obj.magic 0) in
    let ua = Array.create g_per.tlen (Obj.magic 0) in
    do {
      for i = 0 to g_per.tlen - 1 do {
        match g_per.arr.(i) with
        [ Right3 p a u -> do { pa.(i) := p; aa.(i) := a; ua.(i) := u }
        | Left3 lab -> failwith ("undefined person " ^ lab) ]
      };
      (pa, aa, ua)
    }
  in
  let families =
    let fa = Array.create g_fam.tlen (Obj.magic 0) in
    let ca = Array.create g_fam.tlen (Obj.magic 0) in
    let da = Array.create g_fam.tlen (Obj.magic 0) in
    do {
      for i = 0 to g_fam.tlen - 1 do {
        match g_fam.arr.(i) with
        [ Right3 f c d -> do { fa.(i) := f; ca.(i) := c; da.(i) := d }
        | Left3 lab -> failwith ("undefined family " ^ lab) ]
      };
      (fa, ca, da)
    }
  in
  let strings = Array.sub g_str.arr 0 g_str.tlen in
  (persons, families, strings, g_bnot)
;

value cache_of tab =
  let c =
    {array _ = tab; get = fun []; len = Array.length tab; clear_array x = x}
  in
  do { c.get := fun i -> (c.array ()).(i); c }
;

value make_base (persons, families, strings, bnotes) =
  let (persons, ascends, unions) = persons in
  let (families, couples, descends) = families in
  let bnotes = {nread _ = bnotes; norigin_file = ""} in
  let base_data =
    {persons = cache_of persons; ascends = cache_of ascends;
     unions = cache_of unions; families = cache_of families;
     couples = cache_of couples; descends = cache_of descends;
     strings = cache_of strings; bnotes = bnotes}
  in
  let base_func =
    {persons_of_name = fun []; strings_of_fsname = fun [];
     index_of_string = fun [];
     persons_of_surname = {find = fun []; cursor = fun []; next = fun []};
     persons_of_first_name = {find = fun []; cursor = fun []; next = fun []};
     is_restricted = fun []; patch_person = fun []; patch_ascend = fun [];
     patch_union = fun []; patch_family = fun []; patch_couple = fun [];
     patch_descend = fun []; patch_string = fun []; patch_name = fun [];
     commit_patches = fun []; commit_notes = fun []; patched_ascends = fun [];
     cleanup () = ()}
  in
  {data = base_data; func = base_func}
;

value array_memq x a =
  loop 0 where rec loop i =
    if i == Array.length a then False
    else if x == a.(i) then True
    else loop (i + 1)
;

value check_parents_children base =
  let to_delete = ref [] in
  let fam_to_delete = ref [] in
  do {
    for i = 0 to base.data.persons.len - 1 do {
      let a = base.data.ascends.get i in
      match a.parents with
      [ Some ifam ->
          let fam = foi base ifam in
          if fam.fam_index == Adef.ifam_of_int (-1) then a.parents := None
          else
            let cpl = coi base ifam in
            let des = doi base ifam in
            if array_memq (Adef.iper_of_int i) des.children then ()
            else do {
              let p = base.data.persons.get i in
              Printf.fprintf log_oc.val
                "%s is not the child of his/her parents\n"
                (denomination base p);
              Printf.fprintf log_oc.val "- %s\n"
                (denomination base (poi base cpl.father));
              Printf.fprintf log_oc.val "- %s\n"
                (denomination base (poi base cpl.mother));
              Printf.fprintf log_oc.val "=> no more parents for him/her\n";
              Printf.fprintf log_oc.val "\n";
              flush log_oc.val;
              a.parents := None
            }
      | None -> () ];
      fam_to_delete.val := [];
      let u = base.data.unions.get i in
      for j = 0 to Array.length u.family - 1 do {
        let cpl = coi base u.family.(j) in
        if Adef.iper_of_int i <> cpl.father &&
           Adef.iper_of_int i <> cpl.mother
        then do {
          Printf.fprintf log_oc.val
            "%s is spouse in this family but neither husband nor wife:\n"
            (denomination base (base.data.persons.get i));
          Printf.fprintf log_oc.val "- %s\n"
            (denomination base (poi base cpl.father));
          Printf.fprintf log_oc.val "- %s\n"
            (denomination base (poi base cpl.mother));
          let fath = poi base cpl.father in
          let moth = poi base cpl.mother in
          let ffn = sou base fath.first_name in
          let fsn = sou base fath.surname in
          let mfn = sou base moth.first_name in
          let msn = sou base moth.surname in
          if ffn = "?" && fsn = "?" && mfn <> "?" && msn <> "?" then do {
            Printf.fprintf log_oc.val
              "However, the husband is unknown, I set him as husband\n";
            (uoi base cpl.father).family := [| |];
            cpl.father := Adef.iper_of_int i;
          }
          else if mfn = "?" && msn = "?" && ffn <> "?" && fsn <> "?" then do {
            Printf.fprintf log_oc.val
              "However, the wife is unknown, I set her as wife\n";
            (uoi base cpl.mother).family := [| |];
            cpl.mother := Adef.iper_of_int i;
          }
          else do {
            Printf.fprintf log_oc.val "=> deleted this family for him/her\n";
            fam_to_delete.val := [j :: fam_to_delete.val];
          };
          Printf.fprintf log_oc.val "\n";
          flush log_oc.val
        }
        else ()
      };
      if fam_to_delete.val <> [] then
        let (list, _) =
          List.fold_left
            (fun (list, i) x ->
               if List.mem i fam_to_delete.val then (list, i + 1)
               else ([x :: list], i + 1))
            ([], 0) (Array.to_list u.family)
        in
        u.family := Array.of_list (List.rev list)
      else ()
    };
    for i = 0 to base.data.families.len - 1 do {
      to_delete.val := [];
      let fam = base.data.families.get i in
      let cpl = base.data.couples.get i in
      let des = base.data.descends.get i in
      for j = 0 to Array.length des.children - 1 do {
        let a = aoi base des.children.(j) in
        let p = poi base des.children.(j) in
        match a.parents with
        [ Some ifam ->
            if Adef.int_of_ifam ifam <> i then do {
              Printf.fprintf log_oc.val "Other parents for %s\n"
                (denomination base p);
              Printf.fprintf log_oc.val "- %s\n"
                (denomination base (poi base cpl.father));
              Printf.fprintf log_oc.val "- %s\n"
                (denomination base (poi base cpl.mother));
              Printf.fprintf log_oc.val "=> deleted in this family\n";
              Printf.fprintf log_oc.val "\n";
              flush log_oc.val;
              to_delete.val := [p.cle_index :: to_delete.val]
            }
            else ()
        | None ->
            do {
              Printf.fprintf log_oc.val
                "%s has no parents but is the child of\n"
                (denomination base p);
              Printf.fprintf log_oc.val "- %s\n"
                (denomination base (poi base cpl.father));
              Printf.fprintf log_oc.val "- %s\n"
                (denomination base (poi base cpl.mother));
              Printf.fprintf log_oc.val "=> added parents\n";
              Printf.fprintf log_oc.val "\n";
              flush log_oc.val;
              a.parents := Some fam.fam_index
            } ]
      };
      if to_delete.val <> [] then
        let l =
          List.fold_right
            (fun ip l -> if List.memq ip to_delete.val then l else [ip :: l])
            (Array.to_list des.children) []
        in
        des.children := Array.of_list l
      else ()
    }
  }
;

value kill_family base fam ip =
  let u = uoi base ip in
  let l =
    List.fold_right
      (fun ifam ifaml ->
         if ifam == fam.fam_index then ifaml else [ifam :: ifaml])
      (Array.to_list u.family) []
  in
  u.family := Array.of_list l
;

value kill_parents base ip =
  let a = aoi base ip in
  a.parents := None
;

value effective_del_fam base fam cpl des =
  let ifam = fam.fam_index in
  do {
    kill_family base fam cpl.father;
    kill_family base fam cpl.mother;
    Array.iter (kill_parents base) des.children;
    cpl.father := Adef.iper_of_int (-1);
    cpl.mother := Adef.iper_of_int (-1);
    des.children := [| |];
    fam.fam_index := Adef.ifam_of_int (-1)
  }
;

value string_of_sex =
  fun
  [ Male -> "M"
  | Female -> "F"
  | Neuter -> "N" ]
;

value check_parents_sex base =
  for i = 0 to base.data.couples.len - 1 do {
    let cpl = base.data.couples.get i in
    let fam = base.data.families.get i in
    let fath = poi base cpl.father in
    let moth = poi base cpl.mother in
    if fam.relation = NoSexesCheck then ()
    else if fath.sex = Female || moth.sex = Male then do {
      if fath.sex = Female then
        Printf.fprintf log_oc.val "Warning - husband with female sex: %s\n"
          (denomination base fath)
      else ();
      if moth.sex = Male then
        Printf.fprintf log_oc.val "Warning - wife with male sex: %s\n"
          (denomination base moth)
      else ();
      flush log_oc.val;
      fam.relation := NoSexesCheck
    }
    else do { fath.sex := Male; moth.sex := Female }
  }
;

value neg_year_dmy =
  fun
  [ {day = d; month = m; year = y; prec = OrYear y2} ->
      {day = d; month = m; year = - abs y; prec = OrYear (- abs y2);
       delta = 0}
  | {day = d; month = m; year = y; prec = YearInt y2} ->
      {day = d; month = m; year = - abs y; prec = YearInt (- abs y2);
       delta = 0}
  | {day = d; month = m; year = y; prec = p} ->
      {day = d; month = m; year = - abs y; prec = p; delta = 0} ]
;

value neg_year =
  fun
  [ Dgreg d cal -> Dgreg (neg_year_dmy d) cal
  | x -> x ]
;

value neg_year_cdate cd =
  Adef.cdate_of_date (neg_year (Adef.date_of_cdate cd))
;

value rec negative_date_ancestors base p =
  do {
    match Adef.od_of_codate p.birth with
    [ Some d1 -> p.birth := Adef.codate_of_od (Some (neg_year d1))
    | _ -> () ];
    match p.death with
    [ Death dr cd2 -> p.death := Death dr (neg_year_cdate cd2)
    | _ -> () ];
    let u = uoi base p.cle_index in
    for i = 0 to Array.length u.family - 1 do {
      let fam = foi base u.family.(i) in
      match Adef.od_of_codate fam.marriage with
      [ Some d -> fam.marriage := Adef.codate_of_od (Some (neg_year d))
      | None -> () ]
    };
    let a = aoi base p.cle_index in
    match a.parents with
    [ Some ifam ->
        let cpl = coi base ifam in
        do {
          negative_date_ancestors base (poi base cpl.father);
          negative_date_ancestors base (poi base cpl.mother)
        }
    | _ -> () ]
  }
;

value negative_dates base =
  for i = 0 to base.data.persons.len - 1 do {
    let p = base.data.persons.get i in
    match (Adef.od_of_codate p.birth, date_of_death p.death) with
    [ (Some (Dgreg d1 _), Some (Dgreg d2 _)) ->
        if annee d1 > 0 && annee d2 > 0 && strictement_avant_dmy d2 d1 then
          negative_date_ancestors base (base.data.persons.get i)
        else ()
    | _ -> () ]
  }
;

value finish_base base =
  let persons = base.data.persons.array () in
  let ascends = base.data.ascends.array () in
  let unions = base.data.unions.array () in
  let families = base.data.families.array () in
  let descends = base.data.descends.array () in
  let strings = base.data.strings.array () in
  do {
    for i = 0 to Array.length descends - 1 do {
      let des = descends.(i) in
      let children =
        sort_by_date
          (fun ip -> Adef.od_of_codate persons.(Adef.int_of_iper ip).birth)
          (Array.to_list des.children)
      in
      des.children := Array.of_list children
    };
    for i = 0 to Array.length unions - 1 do {
      let u = unions.(i) in
      let family =
        sort_by_date
          (fun ifam ->
             Adef.od_of_codate families.(Adef.int_of_ifam ifam).marriage)
          (Array.to_list u.family)
      in
      u.family := Array.of_list family
    };
    for i = 0 to Array.length persons - 1 do {
      let p = persons.(i) in
      let a = ascends.(i) in
      let u = unions.(i) in
      if a.parents <> None && Array.length u.family != 0 ||
         p.notes <> string_empty.val
      then do {
        if sou base p.first_name = "?" then do {
          p.first_name := string_x.val; p.occ := i
        }
        else ();
        if sou base p.surname = "?" then do {
          p.surname := string_x.val; p.occ := i
        }
        else ()
      }
      else ()
    };
    check_parents_sex base;
    check_parents_children base;
    if try_negative_dates.val then negative_dates base else ();
    check_base base
      (fun x ->
         do { print_base_error base x; Printf.fprintf log_oc.val "\n" })
      (fun
       [ UndefinedSex _ -> ()
       | x ->
           do {
             print_base_warning base x; Printf.fprintf log_oc.val "\n"
           } ]);
    flush log_oc.val
  }
;

value output_command_line bname =
  let bdir =
    if Filename.check_suffix bname ".gwb" then bname else bname ^ ".gwb"
  in
  let oc = open_out (Filename.concat bdir "command.txt") in
  do {
    Printf.fprintf oc "%s" Sys.argv.(0);
    for i = 1 to Array.length Sys.argv - 1 do {
      Printf.fprintf oc " %s" Sys.argv.(i)
    };
    Printf.fprintf oc "\n";
    close_out oc
  }
;

value set_undefined_death_interval s =
  try
    match Stream.of_string s with parser
    [ [: a = number 0; `'-'; b = number 0 :] ->
        do {
          Printf.eprintf "ay %s dy %s\n" a b;
          flush stderr;
          let a = if a = "" then alive_years.val else int_of_string a in
          let b =
            max a (if b = "" then dead_years.val else int_of_string b)
          in
          alive_years.val := a;
          dead_years.val := b;
          Printf.eprintf "ay %d dy %d\n" a b;
          flush stderr
        } ]
  with
  [ Stream.Error _ -> raise (Arg.Bad "bad parameter for -udi")
  | e -> raise e ]
;

(* Main *)

value out_file = ref "a";
value speclist =
  [("-o", Arg.String (fun s -> out_file.val := s),
    "<file>\n       Output data base (default: \"a\").");
   ("-f", Arg.Set force, "\n       Remove data base if already existing");
   ("-log", Arg.String (fun s -> log_oc.val := open_out s),
    "<file>\n       Redirect log trace to this file.");
   ("-lf", Arg.Set lowercase_first_names, "   \
- Lowercase first names -
       Convert first names to lowercase letters, with initials in
       uppercase.");
   ("-ls", Arg.Set lowercase_surnames, "   \
- Lowercase surnames -
       Convert surnames to lowercase letters, with initials in
       uppercase. Try to keep lowercase particles.");
   ("-fne",
    Arg.String
      (fun s ->
         if String.length s = 2 then
           first_names_brackets.val := Some (s.[0], s.[1])
         else
           raise
             (Arg.Bad
                "-fne option must be followed by a 2 characters string")),
    "\
be - First names enclosed -
       When creating a person, if the GEDCOM first name part holds
       a part between 'b' (any character) and 'e' (any character), it
       is considered to be the usual first name: e.g. -fne '\"\"' or
       -fne \"()\".");
   ("-efn", Arg.Set extract_first_names, "  \
- Extract first names -
       When creating a person, if the GEDCOM first name part holds several
       names, the first of this names becomes the person \"first name\" and
       the complete GEDCOM first name part a \"first name alias\".");
   ("-no_efn", Arg.Clear extract_first_names, "  \
- Dont extract first names - [default]
       Cancels the previous option.");
   ("-epn", Arg.Set extract_public_names, "  \
- Extract public names - [default]
       When creating a person, if the GEDCOM first name part looks like a
       public name, i.e. holds:
       * a number or a roman number, supposed to be a number of a
         nobility title,
       * one of the words: \"der\", \"den\", \"die\", \"el\", \"le\", \"la\",
         \"the\", supposed to be the beginning of a qualifier,
       then the GEDCOM first name part becomes the person \"public name\"
       and its first word his \"first name\".");
   ("-no_epn", Arg.Clear extract_public_names,
    "\n       Cancels the previous option.");
   ("-no_pit", Arg.Set no_public_if_titles, " \
- No public if titles -
       Do not consider persons having titles as public");
   ("-tnd", Arg.Set try_negative_dates, "  \
- Try negative dates -
       Set negative dates when inconsistency (e.g. birth after death)");
   ("-no_nd", Arg.Set no_negative_dates, " \
- No negative dates -
       Don't interpret a year preceded by a minus sign as a negative year");
   ("-udi", Arg.String set_undefined_death_interval, "\
x-y   - Undefined death interval -
       Set the interval for persons whose death part is undefined:
       - if before x years, they are considered as alive
       - if after y year, they are considered as death
       - between x and y year, they are considered as \"don't know\"
       Default x is " ^ string_of_int alive_years.val ^ " and y is " ^ string_of_int dead_years.val);
   ("-uin", Arg.Set untreated_in_notes,
    " - Untreated in notes -\n       Put untreated GEDCOM tags in notes");
   ("-ds", Arg.String (fun s -> default_source.val := s), " \
- Default source -
       Set the source field for persons and families without source data");
   ("-dates_dm", Arg.Unit (fun () -> month_number_dates.val := DayMonthDates),
    "\n       Interpret months-numbered dates as day/month/year");
   ("-dates_md", Arg.Unit (fun () -> month_number_dates.val := MonthDayDates),
    "\n       Interpret months-numbered dates as month/day/year");
   ("-charset",
    Arg.String
      (fun
       [ "ANSEL" -> charset_option.val := Some Ansel
       | "ASCII" -> charset_option.val := Some Ascii
       | "MSDOS" -> charset_option.val := Some Msdos
       | _ -> raise (Arg.Bad "bad -charset value") ]),
    "\
[ANSEL|ASCII|MSDOS] - charset decoding -
       Force given charset decoding, overriding the possible setting in
       GEDCOM")]
;

value anonfun s =
  if in_file.val = "" then in_file.val := s
  else raise (Arg.Bad "Cannot treat several GEDCOM files")
;

value errmsg = "Usage: ged2gwb [<ged>] [options] where options are:";

value main () =
  do {
    Argl.parse speclist anonfun errmsg;
    let bdir =
      if Filename.check_suffix out_file.val ".gwb" then out_file.val
      else out_file.val ^ ".gwb"
    in
    if not force.val && Sys.file_exists bdir then do {
      Printf.printf "\
The data base \"%s\" already exists. Use option -f to overwrite it.
"
        out_file.val;
      flush stdout;
      exit 2
    }
    else ();
    let arrays = make_arrays in_file.val in
    Gc.compact ();
    let arrays = make_subarrays arrays in
    let base = make_base arrays in
    finish_base base;
    lock Iobase.lock_file out_file.val with
    [ Accept ->
        do {
          Iobase.output out_file.val base; output_command_line out_file.val
        }
    | Refuse ->
        do {
          Printf.printf "Base is locked: cannot write it\n";
          flush stdout;
          exit 2
        } ];
    warning_month_number_dates ();
    if log_oc.val != stdout then close_out log_oc.val else ()
  }
;

try main () with e ->
  do {
    Printf.fprintf log_oc.val "Uncaught exception: %s\n"
      (Printexc.to_string e);
    close_out log_oc.val;
    exit 2
  };


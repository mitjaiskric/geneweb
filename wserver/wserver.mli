(* $Id: wserver.mli,v 4.0 2001-03-16 19:35:15 ddr Exp $ *)
(* Copyright (c) 2001 INRIA *)

(* module [Wserver]: elementary web service *)

value f :
  option string -> int -> int -> option int ->
    ((Unix.sockaddr * list string) -> string -> string -> unit) -> unit
;
   (* [Wserver.f addr port tmout maxc g] starts an elementary
       httpd server at port [port] in the current machine. The variable
       [addr] is [Some the-address-to-use] or [None] for any of the
       available addresses of the present machine. The port number is
       any number greater than 1024 (to create a client < 1024, you must be
       root). At each connection, the function [g] is called:
       [g (addr, request) scr cont] where [addr] is the client identification
       socket, [request] the browser request, [scr] the script name (extracted
       from [request]) and [cont] the stdin contents . The function
       [g] has [tmout] seconds to answer some text on standard output.
       If [maxc] is [Some n], maximum [n] clients can be treated at the
       same time; [None] means no limit. See the example below. *)

value wprint : format 'a out_channel unit -> 'a;
    (* To be called to print page contents. *)

value wflush : unit -> unit;
    (* To flush page contents print. *)

value html : string -> unit;
    (* [Wserver.html charset] specifies that the text will be HTML.
       where [charset] represents the character set. If empty string,
       iso-8859-1 is assumed. *)

value encode : string -> string;
    (* [Wserver.encode s] encodes the string [s] in another string
       where spaces and special characters are coded. This allows
       to put such strings in html links <a href=...>. This is
       the same encoding done by Web browsers in forms. *)

value decode : string -> string;
    (* [Wserver.decode s] does the inverse job than [Wserver.code],
       restoring the initial string. *)

value extract_param : string -> char -> list string -> string;
    (* [extract_param name stopc request] can be used to extract some
       parameter from a browser [request] (list of strings); [name]
       is a string which should match the beginning of a request line,
       [stopc] is a character ending the request line. For example, the
       string request has been obtained by: [extract_param "GET /" ' '].
       Answers the empty string if the parameter is not found. *)

value get_request_and_content : Stream.t char -> (list string * string);

value sock_in : ref string;
value sock_out : ref string;
value noproc : ref bool;

(* Example:

   - Source program "foo.ml":
        Wserver.f None 2368 60 None (None, None)
           (fun _ s -> Wserver.html (); Wserver.wprint "You said: %s...\n" s);;
   - Compilation:
        ocamlc -custom unix.cma -cclib -lunix wserver.cmo foo.ml
   - Run:
        ./a.out
   - Launch a Web browser and open the location:
        http://localhost:2368/hello   (but see the remark below)
   - You should see a new page displaying the text:
        You said: hello...

  Possible problem: if the browser says that it cannot connect to
      "localhost:2368",
  try:
      "localhost.domain:2368" (the domain where your machine is)
      "127.0.0.1:2368"
      "machine:2368"          (your machine name)
      "machine.domain:2368"   (your machine name)
      "addr:2368"             (your machine internet address)

*)

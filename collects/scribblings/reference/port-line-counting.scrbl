#reader(lib "docreader.ss" "scribble")
@require["mz.ss"]

@title[#:tag "mz:linecol"]{Counting Positions, Lines, and Columns}

@index['("line numbers")]{
@index['("column numbers")]{
@index['("port positions")]{
By}}} default, Scheme keeps track of the @deftech{position} in a port as the
number of bytes that have been read from or written to any port
(independent of the read/write position, which is accessed or changed
with @scheme[file-position]). Optionally, however, Scheme can track
the position in terms of characters (after UTF-8 decoding), instead of
bytes, and it can track @deftech{line locations} and @deftech{column
locations}; this optional tracking must be specifically enabled for a
port via @scheme[port-count-lines!] or the
@scheme[port-count-lines-enabled] parameter. Position, line, and
column locations for a port are used by @scheme[read-syntax] and
@scheme[read-honu-syntax]. Position and line locations are numbered
from @math{1}; column locations are numbered from @math{0}.

When counting lines, Scheme treats linefeed, return, and
return-linefeed combinations as a line terminator and as a single
position (on all platforms). Each tab advances the column count to one
before the next multiple of @math{8}. When a sequence of bytes in the
range 128 to 253 forms a UTF-8 encoding of a character, the
position/column is incremented is incremented once for each byte, and
then decremented appropriately when a complete encoding sequence is
discovered. See also @secref["mz:ports"] for more information on UTF-8
decoding for ports.

A position is known for any port as long as its value can be expressed
as a fixnum (which is more than enough tracking for realistic
applications in, say, syntax-error reporting).  If the position for a
port exceeds the value of the largest fixnum, then the position for
the port becomes unknown, and line and column tacking is disabled.
Return-linefeed combinations are treated as a single character
position only when line and column counting is enabled.

Certain kinds of exceptions (see @secref["mz:exns"]) encapsulate
 source-location information using a @scheme[srcloc] structure.

@;------------------------------------------------------------------------

@defproc[(port-count-lines! [port port?]) void?]{

Turns on line and column counting for a port. Counting can be turned
on at any time, though generally it is turned on before any data is
read from or written to a port. When a port is created, if the value
of the @scheme[port-count-lines-enabled] parameter is true, then line
counting is automatically enabled for the port. Line counting cannot
be disabled for a port after it is enabled.}

@defproc[(port-next-location [port port?]) 
         (values (or/c positive-exact-integer? false/c)
                 (or/c nonnegative-exact-integer? false/c)
                 (or/c positive-exact-integer? false/c))]{

Returns three values: an integer or @scheme[#f] for the line number of
the next read/written item, an integer or @scheme[#f] for the next
item's column, and an integer or @scheme[#f] for the next item's
position. The next column and position normally increases as bytes are
read from or written to the port, but if line/character counting is
enabled for @scheme[port], the column and position results can
decrease after reading or writing a byte that ends a UTF-8 encoding
sequence.}

@defstruct[srcloc ([source any/c]
                   [line (or/c positive-exact-integer? false/c)]
                   [column (or/c nonnegative-exact-integer? false/c)]
                   [position (or/c positive-exact-integer? false/c)]
                   [span (or/c nonnegative-exact-integer? false/c)])
                  #:immutable
                  #:inspector #f]{

The fields of an @scheme[srcloc] instance are as follows:

@itemize{

 @item{@scheme[source] --- An arbitrary value identifying the source,
 often a path (see @secref["mz:pathutils"]).}

 @item{@scheme[line] --- The line number (counts from 1) or
 @scheme[#f] (unknown).}

 @item{@scheme[column] --- The column number (counts from 0) or
 @scheme[#f] (unknown).}

 @item{@scheme[position] --- The starting position (counts from 1) or
 @scheme[#f] (unknown).}

 @item{@scheme[span] --- The number of covered positions (counts from
 0) or @scheme[#f] (unknown).}

}}
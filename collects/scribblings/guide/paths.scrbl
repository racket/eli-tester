#reader(lib "docreader.ss" "scribble")
@require[(lib "manual.ss" "scribble")]
@require[(lib "eval.ss" "scribble")]
@require["guide-utils.ss"]

@title[#:tag "paths"]{Paths}

A @defterm{path} encapsulates a filesystem path that (potentially)
names a file or directory. Although paths can be converted to and from
strings and byte strings, neither strings nor byte strings are
suitable for representing general paths. The problem is that paths are
represented in the filesystem as either byte sequences or UTF-16
sequences (depending on the operating systems); the sequences are not
always human-readable, and not all sequences can be decoded to Unicode
scalar values.

Despite the occasional encoding problems, most paths can be converted
to and fom strings. Thus, procedures that accept a path argument
always accept a string, and the printed form of a path uses the string
decodin of the path inside @schemefont{#<path:} and @scheme{>}. The
@scheme[display] form of a path is the same as the @scheme[display]
form of its string encodings.

@examples[
(string->path "my-data.txt")
(file-exists? "my-data.txt")
(file-exists? (string->path "my-data.txt"))
(display (string->path "my-data.txt"))
]

Produces that produce references to the filesystem always produce path
values, instead of strings.

@examples[
(path-replace-suffix "foo.scm" #".ss")
]

Although it's sometimes tempting to directly manipulate strings that
represent filesystem paths, correctly manipulating a path can be
surprisingly difficult. For example, if you start under Unix with the
aboslute path @file{/tmp/~} and take just the last part, you end up
with @file{~}---which looks like a reference to the current user's
home directory, instead of a relative path to a file of directory
named @file{~}. Windows path manipulation, furthermore, is far
trickier, because path elements like @file{aux} can have special
meanings (see @secref["windows-path"]).

Use procedures like @scheme[split-path] and @scheme[build-path] to
deconstruct and construct paths. When you must manipulate the name of
a specific path element (i.e., a file or directory component in a
path), use procedures like @scheme[path-element->bytes] and
@scheme[bytes->path-element].

@examples[
(build-path "easy" "file.ss")
(split-path (build-path "easy" "file.ss"))
]
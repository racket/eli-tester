#reader(lib "docreader.ss" "scribble")
@require[(lib "manual.ss" "scribble")]
@require[(lib "eval.ss" "scribble")]
@require["guide-utils.ss"]

@title[#:tag "datatypes" #:style 'toc]{Built-In Datatypes}

The @seclink["to-scheme"]{little Scheme section} introduced some of
Scheme's built-in datatype: numbers, booleans, strings, lists, and
procedures. This section provides a more complete coverage of the
built-in datatypes for simple forms of data.

@local-table-of-contents[]

@include-section["booleans.scrbl"]
@include-section["numbers.scrbl"]
@include-section["chars.scrbl"]
@include-section["char-strings.scrbl"]
@include-section["byte-strings.scrbl"]
@include-section["symbols.scrbl"]
@include-section["pairs.scrbl"]
@include-section["vectors.scrbl"]
@include-section["hash-tables.scrbl"]
@include-section["keywords.scrbl"]
@include-section["boxes.scrbl"]
@include-section["void-and-undef.scrbl"]
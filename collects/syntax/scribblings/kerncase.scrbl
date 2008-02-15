#lang scribble/doc
@(require "common.ss"
          (for-label syntax/kerncase))

@(define-syntax-rule (intro id)
  (begin
   (require (for-label mzscheme))
   (define id (scheme if))))
@(intro mzscheme-if)

@; ----------------------------------------------------------------------

@title[#:tag "kerncase"]{Matching Fully-Expanded Expressions}

@defmodule[syntax/kerncase]

@defform[(kernel-syntax-case stx-expr trans?-expr clause ...)]{

A syntactic form like @scheme[syntax-case*], except that the literals
are built-in as the names of the primitive PLT Scheme forms as
exported by @schememodname[scheme/base]; see @secref[#:doc refman
"fully-expanded"].

The @scheme[trans?-expr] boolean expression replaces the comparison
procedure, and instead selects simply between normal-phase comparisons
or transformer-phase comparisons. The @scheme[clause]s are the same as in
@scheme[syntax-case*].

The primitive syntactic forms must have their normal bindings in the
context of the @scheme[kernel-syntax-case] expression. Beware that
@scheme[kernel-syntax-case] does not work in a module whose language
is @scheme[mzscheme], since the binding of @mzscheme-if from
@scheme[mzscheme] is different than the primitive @scheme[if].}


@defform[(kernel-syntax-case* stx-expr trans?-expr (extras ...) clause ...)]{

A syntactic form like @scheme[kernel-syntax-case], except that it
takes an additional list of extra literals that are in addition to the
primitive PLT Scheme forms.}


@defproc[(kernel-form-identifier-list) (listof indentifier?)]{

Returns a list of identifiers that are bound normally,
@scheme[for-syntax], and @scheme[for-template] to the primitive PLT
Scheme forms for expressions. This function is useful for generating a
list of stopping points to provide to @scheme[local-expand].}
#reader(lib "docreader.ss" "scribble")
@require[(lib "manual.ss" "scribble")]
@require[(lib "eval.ss" "scribble")]
@require["guide-utils.ss"]

@title[#:tag "void+undefined"]{Void and Undefined}

Some procedures or expression forms have no need for a result
value. For example, the @scheme[display] procedure is called only for
the side-effect of writing output. In such cases the reslt value is
normally a special constant that prints as @void-const[].  When the
result of an expression is simply @void-const[], the REPL does not
print anything.

The @scheme[void] procedure takes any number of arguments and returns
@void-const[]. (That is, the identifier @schemeidfont{void} is bound
to a procedure that returns @void-const[], instead of being bound
directly to @void-const[].)

@examples[
(void)
(void 1 2 3)
(list (void))
]

A constant that prints as @schemefont{#<undefined>} is used as the
result of a reference to a local binding when the binding is not yet
initialized. Such early references are not possible for bindings that
corerspond to procedure arguments, @scheme[let] bindings, or
@scheme[let*] bindings; early reference requires a recursive binding
context, such as @scheme[letrec] or local @scheme[define]s in a
procedure body. Also, early references to top-level and module
top-level bindings raise an exception, instead of producing
@schemefont{#<undefined>}. For these reasons,
@schemefont{#<undefined>} rarely appears.

@def+int[
(define (strange)
  (define x x)
  x)
(strange)
]

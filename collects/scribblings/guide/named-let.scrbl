#reader(lib "docreader.ss" "scribble")
@require[(lib "manual.ss" "scribble")]
@require[(lib "eval.ss" "scribble")]
@require["guide-utils.ss"]

@title{Named @scheme[let]}

A named @scheme[let] is an iteration and recursion form. It uses the
same syntactic keyword @scheme[let] as for local binding, but an
identifier after the @scheme[let] (instead of an immediate open
parenthesis) triggers a different parsing.

In general,

@schemeblock[
(let _proc-id ([_arg-id _init-expr] ...)
  _body-expr ...+)
]

is equivalent to

@schemeblock[
(letrec ([_proc-id (lambda (_arg-id ...)
                     _body-expr ...+)])
  (_proc-id _init-expr ...))
]

That is, a named @scheme[let] binds a procedure identifier that is
visible only in the procedure's body, and it implicitly calls the
procedure with the values of some initial expressions. 

@defexamples[
(define (duplicate pos lst)
  (let dup ([i 0]
            [lst lst])
   (cond
    [(= i pos) (cons (car lst) lst)]
    [else (cons (car lst) (dup (+ i 1) (cdr lst)))])))
(duplicate 1 (list "apple" "cheese burger!" "banana"))
]

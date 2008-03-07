#lang scribble/doc

@begin[(require scribble/manual)
       (require (for-label typed-scheme))]

@begin[
(define (item* header . args) (apply item @bold[header]{: } args))
(define-syntax-rule (tmod forms ...) (schememod typed-scheme forms ...))
]

@title[#:tag "top"]{@bold{Typed Scheme}: Scheme with Static Types}

@(defmodulelang typed-scheme)

Typed Scheme is a Scheme-like language, with a type system that
supports common Scheme programming idioms.  Explicit type declarations
are required --- that is, there is no type inference.  The language
supports a number of features from previous work on type systems that
make it easier to type Scheme programs, as well as a novel idea dubbed
@italic{occurrence typing} for case discrimination.

Typed Scheme is also designed to integrate with the rest of your PLT
Scheme system.  It is possible to convert a single module to Typed
Scheme, while leaving the rest of the program unchanged.  The typed
module is protected from the untyped code base via
automatically-synthesized contracts.

Further information on Typed Scheme is available from
@link["http://www.ccs.neu.edu/home/samth/typed-scheme"]{the homepage}.

@section{Starting with Typed Scheme}

If you already know PLT Scheme, or even some other Scheme, it should be
easy to start using Typed Scheme.

@subsection{A First Function}

The following program defines the Fibonacci function in PLT Scheme:

@schememod[scheme
(define (fib n)
  (cond [(= 0 n) 1]
	[(= 1 n) 1]
	[else (+ (fib (- n 1)) (fib (- n 2)))]))
]

This program defines the same program using Typed Scheme.
 
@schememod[typed-scheme
(: fib (Number -> Number))
(define (fib n)
  (cond [(= 0 n) 1]
        [(= 1 n) 1]
        [else (+ (fib (- n 1)) (fib (- n 2)))]))
]

There are two differences between these programs:

@itemize{
  @item*[@elem{The Language}]{@schememodname[scheme] has been replaced by @schememodname[typed-scheme].}

  @item*[@elem{The Type Annotation}]{We have added a type annotation
for the @scheme[fib] function, using the @scheme[:] form.}  }

In general, these are most of the changes that have to be made to a
PLT Scheme program to transform it into a Typed Scheme program.
@margin-note{Changes to uses of @scheme[require] may also be necessary
- these are described later.}

@subsection[#:tag "complex"]{Adding more complexity}

Other typed binding forms are also available.  For example, we could have
rewritten our fibonacci program as follows:

@schememod[typed-scheme
(: fib (Number -> Number))
(define (fib n)
  (let ([base? (or (= 0 n) (= 1 n))])
    (if base? 1
        (+ (fib (- n 1)) (fib (- n 2))))))
]

This program uses the @scheme[let] binding form, but no new type
annotations are required.  Typed Scheme infers the type of
@scheme[base?].  

We can also define mutually-recursive functions:

@schememod[typed-scheme
(: my-odd? (Number -> Boolean))
(define (my-odd? n)
  (if (= 0 n) #f
      (my-even? (- n 1))))

(: my-even? (Number -> Boolean))
(define (my-even? n)
  (if (= 0 n) #t
      (my-odd? (- n 1))))

(display (my-even? 12))
]

As expected, this program prints @schemeresult[#t].


@subsection{Defining New Datatypes}

If our program requires anything more than atomic data, we must define
new datatypes.  In Typed Scheme, structures can be defined, similarly
to PLT Scheme structures.  The following program defines a date
structure and a function that formats a date as a string, using PLT
Scheme's built-in @scheme[format] function.

@schememod[typed-scheme
(define-typed-struct Date ([day : Number] [month : String] [year : Number]))

(: format-date (Date -> String))
(define (format-date d)
  (format "Today is day ~a of ~a in the year ~a" 
          (Date-day d) (Date-month d) (Date-year d)))

(display (format-date (make-Date 28 "November" 2006)))
]

Here we see the new built-in type @scheme[String] as well as a definition
of the new user-defined type @scheme[my-date].  To define
@scheme[my-date], we provide all the information usually found in a
@scheme[define-struct], but added type annotations to the fields using
the @scheme[define-typed-struct] form.
Then we can use the functions that this declaration creates, just as
we would have with @scheme[define-struct].


@subsection{Recursive Datatypes and Unions}

Many data structures involve multiple variants.  In Typed Scheme, we
represent these using @italic{union types}, written @scheme[(U t1 t2 ...)].

@schememod[typed-scheme
(define-type-alias Tree (U leaf node))
(define-typed-struct leaf ([val : Number]))
(define-typed-struct node ([left : Tree] [right : Tree]))

(: tree-height (Tree -> Number))
(define (tree-height t)
  (cond [(leaf? t) 1]
        [else (max (tree-height (node-left t))
                   (tree-height (node-right t)))]))

(: tree-sum (Tree -> Number))
(define (tree-sum t)
  (cond [(leaf? t) (leaf-val t)]
        [else (+ (tree-sum (node-left t))
                 (tree-sum (node-right t)))]))
]

In this module, we have defined two new datatypes: @scheme[leaf] and
@scheme[node].  We've also defined the type alias @scheme[Tree] to be
@scheme[(U node leaf)], which represents a binary tree of numbers.  In
essence, we are saying that the @scheme[tree-height] function accepts
a @scheme[Tree], which is either a @scheme[node] or a @scheme[leaf],
and produces a number.

In order to calculate interesting facts about trees, we have to take
them apart and get at their contents.  But since accessors such as
@scheme[node-left] require a @scheme[node] as input, not a
@scheme[Tree], we have to determine which kind of input we
were passed.  

For this purpose, we use the predicates that come with each defined
structure.  For example, the @scheme[leaf?] predicate distinguishes
@scheme[leaf]s from all other Typed Scheme values.  Therefore, in the
first branch of the @scheme[cond] clause in @scheme[tree-sum], we know
that @scheme[t] is a @scheme[leaf], and therefore we can get its value
with the @scheme[leaf-val] function.

In the else clauses of both functions, we know that @scheme[t] is not
a @scheme[leaf], and since the type of @scheme[t] was @scheme[Tree] by
process of elimination we can determine that @scheme[t] must be a
@scheme[node].  Therefore, we can use accessors such as
@scheme[node-left] and @scheme[node-right] with @scheme[t] as input.

@section{Polymorphism}

Virtually every Scheme program uses lists and sexpressions.  Fortunately, Typed
Scheme can handle these as well.  A simple list processing program can be
written like this:

@schememod[typed-scheme
(: sum-list ((Listof Number) -> Number))
(define (sum-list l)
  (cond [(null? l) 0]
        [else (+ (car l) (sum-list (cdr l)))]))
]

This looks similar to our earlier programs --- except for the type
of @scheme[l], which looks like a function application.  In fact, it's
a use of the @italic{type constructor} @scheme[Listof], which takes
another type as its input, here @scheme[Number].  We can use
@scheme[Listof] to construct the type of any kind of list we might
want.  

We can define our own type constructors as well.  For example, here is
an analog of the @tt{Maybe} type constructor from Haskell:

@schememod[typed-scheme
(define-typed-struct Nothing ())
(define-typed-struct (a) Just ([v : a]))

(define-type-alias (Maybe a) (U Nothing (Just a)))

(: find (Number (Listof Number) -> (Maybe Number)))
(define (find v l)
  (cond [(null? l) (make-Nothing)]
        [(= v (car l)) (make-Just v)]
        [else (find v (cdr l))]))
]

The first @scheme[define-typed-struct] defines @scheme[Nothing] to be
a structure with no contents.  

The second definition

@schemeblock[
(define-typed-struct (a) Just ([v : a]))
]

creates a parameterized type, @scheme[Just], which is a structure with
one element, whose type is that of the type argument to
@scheme[Just].  Here the type parameters (only one, @scheme[a], in
this case) are written before the type name, and can be referred to in
the types of the fields.

The type alias definiton
@schemeblock[
  (define-type-alias (Maybe a) (U Nothing (Just a)))
]
creates a parameterized alias --- @scheme[Maybe] is a potential
container for whatever type is supplied.

The @scheme[find] function takes a number @scheme[v] and list, and
produces @scheme[(make-Just v)] when the number is found in the list,
and @scheme[(make-Nothing)] otherwise.  Therefore, it produces a
@scheme[(Maybe Number)], just as the annotation specified.  

@section[#:tag "type-ref"]{Type Reference}

@subsubsub*section{Base Types}
These types represent primitive Scheme data.
@defidform[Number]{Any number}
@defidform[Boolean]{Either @scheme[#t] or @scheme[#f]}
@defidform[String]{A string}
@defidform[Keyword]{A PLT Scheme literal keyword}
@defidform[Symbol]{A symbol}
@defidform[Any]{Any value}

@subsubsub*section{Type Constructors}
The following constructors are parameteric in their type arguments.

@defform[(Listof t)]{Homogenous lists of @scheme[t]}
@defform[(Vectorof t)]{Homogenous vectors of @scheme[t]}
@defform[(Option t)]{Either @scheme[t] of @scheme[#f]}

@;{
@schemeblock[
(define: f : (Number -> Number) (lambda: ([x : Number]) 3))
]
}

@begin[
(require (for-syntax scheme/base))
(define-syntax (definfixform stx)
  (syntax-case stx ()
    [(_ dummy . rest) #'(begin (specform . rest))]))
#;
(define-syntax (definfixform stx)
  (syntax-case stx ()
    [(_ id spec desc ...)
     #'(*defforms (quote-syntax id) 
		  '()
		  '(spec) 
		  (list (lambda (x) (schemeblock0 spec)))
		  '()
		  '()
		  (lambda () (list desc ...)))]))
]

@defform[(Pair s t)]{is the pair containing @scheme[s] as the @scheme[car]
  and @scheme[t] as the @scheme[cdr]}
@defform[(-> dom ... rng)]{is the type of functions from the (possibly-empty)
  sequence @scheme[dom ...] to the @scheme[rng] type.}
@defform[(U t ...)]{is the union of the types @scheme[t ...]}
@defform[(case-lambda fun-ty ...)]{is a function that behaves like all of
  the @scheme[fun-ty]s.  The @scheme[fun-ty]s must all be function
  types constructed with @scheme[->].}
@defform/none[(t t1 t2 ...)]{is the instantiation of the parametric type
  @scheme[t] at types @scheme[t1 t2 ...]}
@defform[(All (v ...) t)]{is a parameterization of type @scheme[t], with
  type variables @scheme[v ...]}
@defform[(values t ...)]{is the type of a sequence of multiple values, with
types @scheme[t ...].  This can only appear as the return type of a
function.}
@defform/none[v]{where @scheme[v] is a number, boolean or string, is the singleton type containing
only that value}
@defform/none[i]{where @scheme[i] is an identifier can be a reference to a type
name or a type variable}
@defform[(Rec n t)]{is a recursive type where @scheme[n] is bound to the
recursive type in the body @scheme[t]}

Other types cannot be written by the programmer, but are used
internally and may appear in error messages.

@defform/none[(struct:n (t ...))]{is the type of structures named
@scheme[n] with field types @scheme[t].  There may be multiple such
types with the same printed representation.}
@defform/none[<n>]{is the printed representation of a reference to the
type variable @scheme[n]}

@section[#:tag "special-forms"]{Special Form Reference}

Typed Scheme provides a variety of special forms above and beyond
those in PLT Scheme.  They are used for annotating variables with types,
creating new types, and annotating expressions.

@subsection{Binding Forms}

@scheme[_loop], @scheme[_f], @scheme[_a], and @scheme[_v] are names, @scheme[_t] is a type.
 @scheme[_e] is an expression and @scheme[_body] is a block.

@defform*[[(define: (f [v : t] ...) : t body)
	   (define: v : t e)]]{}
@defform[
  (pdefine: (a ...) (f [v : t] ...) : t body)]{}

@defform*[[
  (let: ([v : t e] ...) body)
  (let: loop : t0 ([v : t e] ...) body)]]{where @scheme[_t0] is the type of the
  result of @scheme[_loop] (and thus the result of the entire expression).}
@defform[
  (letrec: ([v : t e] ...) body)]{}
@defform[
  (let*: ([v : t e] ...) body)]{}
@defform*[[
  (lambda: ([v : t] ...) body)
  (lambda: ([v : t] ... . [v : t]) body)]]{}
@defform*[[
  (plambda: (a ...) ([v : t] ...) body)
  (plambda: (a ...) ([v : t] ... . [v : t]) body)]]{}
@defform[
  (case-lambda: [formals body] ...)]{where @scheme[_formals] is like
  the second element of a @scheme[lambda:]}
@defform[
  (pcase-lambda: (a ...) [formals body] ...)]{where @scheme[_formals] is like
  the third element of a @scheme[plambda:]}


@subsection{Structure Definitions}
@defform*[[
(define-typed-struct name ([f : t] ...))
(define-typed-struct (name parent) ([f : t] ...))
(define-typed-struct (v ...) name ([f : t] ...))
(define-typed-struct (v ...) (name parent) ([f : t] ...))]]

@subsection{Type Aliases}
@defform*[[(define-type-alias name t)
	   (define-type-alias (name v ...) t)]]{}


@subsection{Type Annotation}

@defform[
(: v t)
]

@litchar{#{v : t}} This is legal only for binding occurences of @scheme[_v].

@litchar{#{e :: t}} This is legal only in expression contexts.


@subsection{Require}

Here, @scheme[_m] is a module spec, @scheme[_pred] is an identifier
naming a predicate, and @scheme[_r] is an optionally-renamed identifier.

@defform*[[
(require/typed r t m)
(require/typed m [r t] ...)
]]{}

@defform[(require/opaque-type t pred m)]{}

@defform[(require-typed-struct name ([f : t] ...) m)]{}
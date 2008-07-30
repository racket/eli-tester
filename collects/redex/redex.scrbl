#lang scribble/doc
@(require scribble/manual
          scribble/bnf
          scribble/eval
          (for-label scheme/base
                     scheme/contract
		     redex))

@;{

I usually use an `ellipsis' non-terminal to make it more explicit that
the "..." (the only production of `ellipsis') is literal.
- Hide quoted text -

At Wed, 30 Jul 2008 12:49:43 -0500, "Robby Findler" wrote:
> Also, how have you been notating a literal ellipsis in the docs? That
> is, the "c" below should really be a literal ellipsis (as disctinct
> from a repetition of "b")?

}


@;{

I use `defidform'. See `else' for an example.
- Hide quoted text -

At Wed, 30 Jul 2008 13:03:07 -0500, "Robby Findler" wrote:
> One more question: I export --> and fresh from collects/redex/main.ss
> so that I can signal a syntax error if they are used outside of
> reduction-relation. But this causes scribble to complain when I don't
> document them. Is there a standard way to document them?
>
> Robby
}

@(declare-exporting redex)
@title{@bold{PLT Redex}: an embedded DSL for debugging operational semantics}

This collection provides these files:

  _reduction-semantics.ss_: the core reduction semantics
  library

  _gui.ss_: a _visualization tool for reduction sequences_.

  _pict.ss_: a library for _generating picts and postscript from semantics_

In addition, the examples subcollection contains several
small languages to demonstrate various different uses of
this tool:

  _arithmetic.ss_: an arithmetic language with every
  possible order of evaluation

  _beginner.ss_: a PLT redex implementation of (much of) the
  beginning student teaching language.

  _church.ss_: church numerals with call by name
  normal order evaluation

  _combinators.ss_: fills in the gaps in a proof in
  Barendregt that i and j (defined in the file) are
  a combinator basis

  _compatible-closure.ss_: an example use of compatible
  closure. Also, one of the first examples from Matthias
  Felleisen and Matthew Flatt's monograph

  _eta.ss_: shows how eta is, in general, unsound.

  _ho-contracts.ss_: computes the mechanical portions of a
  proof in the Contracts for Higher Order Functions paper
  (ICFP 2002). Contains a sophisticated example use of an
  alternative pretty printer.

  iswim.ss : see further below.

  _macro.ss_: models macro expansion as a reduction semantics.

  _letrec.ss_: shows how to model letrec with a store and
  some infinite looping terms

  _omega.ss_: the call by value lambda calculus with call/cc.
  Includes omega and two call/cc-based infinite loops, one of
  which has an ever-expanding term size and one of which has
  a bounded term size.

  _semaphores.ss_: a simple threaded language with semaphores

  _subject-reduction.ss_: demos traces/pred that type checks
  the term.

  _threads.ss_: shows how non-deterministic choice can be
  modeled in a reduction semantics. Contains an example use
  of a simple alternative pretty printer.

  _types.ss_: shows how the simply-typed lambda calculus's
  type system can be written as a rewritten system (see
  Kuan, MacQueen, Findler in ESOP 2007 for more).

======================================================================

The _reduction-semantics.ss_ library defines a pattern
language, used in various ways:

@(schemegrammar* #:literals (any number string variable variable-except variable-prefix variable-not-otherwise-mentioned hole name in-hole in-named-hole side-condition cross) 
   [pattern any 
            number 
            string 
            variable 
            (variable-except symbol ...)
            (variable-prefix symbol)
            variable-not-otherwise-mentioned
            hole
            (hole symbol-or-false)
            symbol
            (name symbol pattern)
            (in-hole pattern pattern)
            (in-named-hole symbol pattern pattern)
            (hide-hole pattern)
            (side-condition pattern guard)
            (cross symbol)
            (pattern-sequence ...)
            scheme-constant]
   [pattern-sequence 
     pattern 
     ...            ;; literal ellipsis
     ..._id])

The patterns match sexpressions. The _any_ pattern matches
any sepxression. The _number_ pattern matches any
number. The _string_ pattern matches any string. Those three
patterns may also be suffixed with an underscore and another
identifier, in which case they bind the full name (as if it
were an implicit `name' pattern) and match the portion
before the underscore.

The _variable_ pattern matches any symbol. The
_variable-except_ pattern matches any variable except those
listed in its argument. This is useful for ensuring that
keywords in the language are not accidentally captured by
variables. The _variable-prefix_ pattern matches any symbol
that begins with the given prefix. The
_variable-not-otherwise-mentioned_ pattern matches any
symbol except those that are used as literals elsewhere in
the language.

The _hole_ pattern matches anything when inside a matching
in-hole pattern. The (hole <symbol-or-false>) variation on
that pattern is used in conjunction with in-named-hole to
support languages that require multiple patterns in a
hole. If the hole pattern is not being matched as part of
matching an in-hole pattern, it only matches the hole
(extracted as the result of some earlier match of the
in-hole pattern).

NOTE: If you wish to make a two element list whose elements
      are both holes, you must write this:

      ((hole #f) hole)

      If you were to write this: (hole hole), that would be
      interpreted as a single hole whose name is "hole".

The _<symbol>_ pattern stands for a literal symbol that must
match exactly, unless it is the name of a non-terminal in a
relevant language or contains an underscore. 

If it is a non-terminal, it matches any of the right-hand
sides of that non-terminal.

If the symbol is a non-terminal followed by an underscore,
for example e_1, it is implicitly the same as a name pattern
that matches only the non-terminal, (name e_1 e) for the
example. Accordingly, repeated uses of the same name are
constrainted to match the same expression.

If the symbol is a non-terminal followed by _!_, for example
e_!_1, it is also treated as a pattern, but repeated uses of
the same pattern are constrained to be different. For
example, this pattern:

  (e_!_1 e_!_1 e_!_1)

matches lists of three "e"s, but where all three of them are
distinct.

Unlike the _ patterns, the _!_ patterns do not bind names.

If _ names and _!_ are mixed, they are treated as
separate. That is, this pattern (e_1 e_!_1) matches just the
same things as (e e), but the second doesn't bind any
variables.

If the symbol otherwise has an underscore, it is an error.

_name_: The pattern:

  (name <symbol> <pattern>)

matches <pattern> and binds using it to the name <symbol>. 

_in-hole_: The (in-hole <pattern> <pattern>) matches the first
pattern. This match must include exactly one match against the second
pattern. If there are zero or more than one match, an
exception is raised.

When matching the first argument of in-hole, the `hole' pattern
matches any sexpression. Then, the sexpression that matched the hole
pattern is used to match against the second pattern.

_in-named-hole_: The pattern:

   (in-named-hole <symbol> <pattern> <pattern>) 

is similar in spirit to in-hole, except that it supports
languages with multiple holes in a context. The first
argument identifies which hole, using the (hole <symbol>)
pattern that this expression requires and the rest of the
arguments are just like in-hole. That is, if there are
multiple holes in a term, each matching a different (hole
<name>) pattern, this one selects only the holes that are
named by the first argument to in-named-hole.

_hide-hole_: The (hide-hole pattern) pattern matches what
the embedded pattern matches but if the pattern matcher is
looking for a decomposition, it ignores any holes found in
that pattern.

_side-condition_: The (side-condition pattern guard) pattern matches
what the embedded pattern matches, and then the guard expression is
evaluated. If it returns #f, the pattern fails to match, and if it
returns anything else, the pattern matches. In addition, any
occurrences of `name' in the pattern are bound using `term-let'
(see below) in the guard.

_cross_: The (cross <symbol>) pattern is used for the compatible
closure functions. If the language contains a non-terminal with the
same name as <symbol>, the pattern (cross <symbol>) matches the
context that corresponds to the compatible closure of that
non-terminal.

The (pattern-sequence ...) pattern matches a sexpression
list, where each pattern-sequence element matches an element
of the list. In addition, if a list pattern contains an
ellipsis, the ellipsis is not treated as a literal, instead
it matches any number of duplications of the pattern that
came before the ellipses (including 0). Furthermore, each
(name <symbol> <pattern>) in the duplicated pattern binds a
list of matches to <symbol>, instead of a single match.  (A
nested duplicated pattern creates a list of list matches,
etc.) Ellipses may be placed anywhere inside the row of
patterns, except in the first position or immediately after
another ellipses.

Multiple ellipses are allowed. For example, this pattern:

  ((name x a) ... (name y a) ...)

matches this sexpression:

  (a a)

three different ways. One where the first a in the pattern
matches nothing, and the second matches both of the
occurrences of `a', one where each named pattern matches a
single `a' and one where the first matches both and the
second matches nothing.

If the ellipses is named (ie, has an underscore and a name
following it, like a variable may), the pattern matcher
records the length of the list and ensures that any other
occurrences of the same named ellipses must have the same
length. 

As an example, this pattern:

  ((name x a) ..._1 (name y a) ..._1)

only matches this sexpression:

  (a a)

one way, with each named pattern matching a single a. Unlike
the above, the two patterns with mismatched lengths is ruled
out, due to the underscores following the ellipses.

Also, like underscore patterns above, if an underscore
pattern begins with ..._!_, then the lengths must be
different.

Thus, with the pattern:

  ((name x a) ..._!_1 (name y a) ..._!_1)

and the expression

  (a a)

two matches occur, one where x is bound to '() and y is
bound to '(a a) and one where x is bound to '(a a) and y is
bound to '().

@defform/subs[(define-language lang-name 
                (non-terminal-spec pattern ...)
                ...)
              ([non-terminal-spec symbol (symbol ...)])]{

This form defines the grammar of a language. It allows the
definition of recursive patterns, much like a BNF, but for
regular-tree grammars. It goes beyond their expressive
power, however, because repeated `name' patterns and
side-conditions can restrict matches in a context-sensitive
way.

The non-terminal-spec can either by a symbol, indicating a
single name for this non-terminal, or a sequence of symbols,
indicating that all of the symbols refer to these
productions.

As a simple example of a grammar, this is the lambda
calculus:

@schemeblock[
  (define-language lc-lang
    (e (e e ...)
       x
       v)
    (c (v ... c e ...)
       hole)
    (v (lambda (x ...) e))
    (x variable-not-otherwise-mentioned))
]

with non-terminals @scheme[e] for the expression language, @scheme[x] for
variables, @scheme[c] for the evaluation contexts and @scheme[v] for values.
}

@defform[(define-extended-language language language
           (non-terminal pattern ...)
           ...)]{

This form extends a language with some new, replaced, or
extended non-terminals. For example, this language:

@schemeblock[
  (define-extended-language lc-num-lang
    lc-lang
    (e ....     (code:comment "extend the previous `e' non-terminal")
       +
       number)
    (v ....
       + 
       number)
    (x (variable-except lambda +)))
]

extends lc-lang with two new alternatives for both the @scheme[e]
and @scheme[v] nonterminal, replaces the @scheme[x] non-terminal with a
new one, and carries the @scheme[c] non-terminal forward. 

The four-period ellipses indicates that the new language's
non-terminal has all of the alternatives from the original
language's non-terminal, as well as any new ones. If a
non-terminal occurs in both the base language and the
extension, the extension's non-terminal replaces the
originals. If a non-terminal only occurs in either the base
language, then it is carried forward into the
extension. And, of course, extend-language lets you add new
non-terminals to the language.

If a language is has a group of multiple non-terminals
defined together, extending any one of those non-terminals
extends all of them.
}

@defproc[(language-nts [lang compiled-lang?]) (listof symbol?)]{

Returns the list of non-terminals (as symbols) that are
defined by this language.
}

@defproc[(compiled-lang? [l any/c]) boolean?]{

Returns #t if its argument was produced by `language', #f
otherwise.
}

@defform/subs[(term-let ([tl-pat expr] ...) body)
              ([tl-pat identifier (tl-pat-ele ...)]
               [tl-pat-ele tl-pat (code:line tl-pat ellipses)])]{

Matches each given id pattern to the value yielded by
evaluating the corresponding expr and binds each variable in
the id pattern to the appropriate value (described
below). These bindings are then accessible to the `term'
syntactic form.

Identifier-patterns are terms in the following grammar:

where ellipses is the literal symbol consisting of three
dots (and the ... indicates repetition as usual). If tl-pat
is an identifier, it matches any value and binds it to the
identifier, for use inside `term'. If it is a list, it
matches only if the value being matched is a list value and
only if every subpattern recursively matches the
corresponding list element. There may be a single ellipsis
in any list pattern; if one is present, the pattern before
the ellipses may match multiple adjacent elements in the
list value (possibly none).
}

@defform[(term s-expr)]{

This form is used for construction of new s-expressions in
the right-hand sides of reductions. It behaves similarly to
quasiquote except for a few special forms that are
recognized (listed below) and that names bound by `term-let' are
implicitly substituted with the values that those names were
bound to, expanding ellipses as in-place sublists (in the
same manner as syntax-case patterns).

For example,

@schemeblock[
(term-let ([body '(+ x 1)]
           [(expr ...) '(+ - (values * /))]
           [((id ...) ...) '((a) (b) (c d))])
  (term (let-values ([(id ...) expr] ...) body)))
]

evaluates to

@schemeblock[
'(let-values ([(a) +] 
              [(b) -] 
              [(c d) (values * /)]) 
   (+ x 1))
]

It is an error for a term variable to appear in an
expression with an ellipsis-depth different from the depth
with which it was bound by `term-let'. It is also an error
for two `term-let'-bound identifiers bound to lists of
different lengths to appear together inside an ellipsis.

The special forms recognized by term are:

@itemize{
@item{@scheme[(in-hole a b)]

    This is the dual to the pattern `in-hole' -- it accepts
    a context and an expression and uses `plug' to combine
    them.
}@item{@scheme[(in-named-hole name a b)]

    Like in-hole, but substitutes into a hole with a particular name.

}@item{@scheme[hole]

   This produces a hole.
}@item{@scheme[(hole name)]

    This produces a hole with the name `name'. To produce an unnamed
    hole, use #f as the name.
}}}

@defform[(term-match language [pattern expression] ...)]{

This produces a procedure that accepts term (or quoted)
expressions and checks them against each pattern. The
function returns a list of the values of the expression
where the pattern matches. If one of the patterns matches
multiple times, the expression is evaluated multiple times,
once with the bindings in the pattern for each match.
}

@defform[(term-match/single language [pattern expression] ...)]{

This produces a procedure that accepts term (or quoted)
expressions and checks them against each pattern. The
function returns the expression behind the first sucessful
match. If that pattern produces multiple matches, an error
is signaled. If no patterns match, an error is signaled.
}

@defform/subs[#:literals (--> fresh side-condition where) 
              (reduction-relation language reduction-case ...)
              ((reduction-case (--> pattern exp extras ...))
               (extras name
                       (fresh <fresh-clause> ...)
                       (side-condition <guard> ...)
                       (where <tl-pat> e))
               (fresh-clause var ((var1 ...) (var2 ...))))]{

Defines a reduction relation casewise, one case for each of the
clauses beginning with @scheme[-->]. Each of the @scheme[pattern]s
refers to the @scheme[language], and binds variables in the
@scheme[exp]. The @scheme[exp] behave like the argument to
@scheme[term].

Following the lhs & rhs specs can be the name of the
reduction rule, declarations of some fresh variables, and/or
some side-conditions. The name can either be a literal
name (identifier), or a literal string. 

The fresh variables clause generates variables that do not
occur in the term being matched. If the @scheme[fresh-clause] is a
variable, that variable is used both as a binding in the
rhs-exp and as the prefix for the freshly generated
variable. 

The second case of a @scheme[fresh-clause] is used when you want to
generate a sequence of variables. In that case, the ellipses
are literal ellipses; that is, you must actually write
ellipses in your rule. The variable var1 is like the
variable in first case of a @scheme[fresh-clause], namely it is
used to determine the prefix of the generated variables and
it is bound in the right-hand side of the reduction rule,
but unlike the single-variable fresh clause, it is bound to
a sequence of variables. The variable var2 is used to
determine the number of variables generated and var2 must be
bound by the left-hand side of the rule.

The side-conditions are expected to all hold, and have the
format of the second argument to the side-condition pattern,
described above.

Each @scheme[where] clauses binds a variable and the side-conditions
(and @scheme[where] clauses) that follow the where declaration are in
scope of the where declaration. The bindings are the same as
bindings in a @scheme[term-let] expression.

As an example, this

@schemeblock[
  (reduction-relation
   lc-lang
   (--> (in-hole c_1 ((lambda (variable_i ...) e_body) v_i ...))
        (in-hole c_1 ,(foldl lc-subst 
                             (term e_body) 
                             (term (v_i ...)) 
                             (term (variable_i ...))))
        beta-v))
]

defines a reduction relation for the lambda-calculus above.
}

@defform/none[#:literals (with reduction-relation)
         (reduction-relation 
          language
          (arrow-var pattern exp) ...
          with
          [(arrow pattern exp)
           (arrow-var var var)] ...)]{

Defines a reduction relation with shortcuts. As above, the
first section defines clauses of the reduction relation, but
instead of using -->, those clauses can use any identifier
for an arrow, as long as the identifier is bound after the
`with' clause. 

Each of the clauses after the `with' define new relations
in terms of other definitions after the `with' clause or in
terms of the main --> relation.

[ NOTE: `fresh' is always fresh with respect to the entire
  term, not just with respect to the part that matches the
  right-hand-side of the newly defined arrow. ]

For example, this

@schemeblock[
  (reduction-relation
   lc-num-lang
   (==> ((lambda (variable_i ...) e_body) v_i ...)
        ,(foldl lc-subst 
                (term e_body) 
                (term (v_i ...)) 
                (term (variable_i ...))))
   (==> (+ number_1 ...)
        ,(apply + (term (number_1 ...))))
   
   with
   [(--> (in-hole c_1 a) (in-hole c_1 b))
    (==> a b)])
]
  
defines reductions for the lambda calculus with numbers,
where the @tt{==>} relation is defined by reducing in the context
@tt{c}.
}

@defform[(extend-reduction-relation reduction-relation language more ...)]{

This form extends the reduction relation in its first
argument with the rules specified in <more>. They should
have the same shape as the the rules (including the `with'
clause) in an ordinary reduction-relation.

If the original reduction-relation has a rule with the same
name as one of the rules specified in the extension, the old
rule is removed.

In addition to adding the rules specified to the existing
relation, this form also reinterprets the rules in the
original reduction, using the new language.
}
@defproc[(union-reduction-relations [r reduction-relation?] ...) reduction-relation?]{

Combines all of the argument reduction relations into a
single reduction relation that steps when any of the
arguments would have stepped.
}

@defproc[(reduction-relation->rule-names [r reduction-relation?])
         (listof (union false/c symbol?))]{

Returns the names of all of the reduction relation's clauses
(or false if there is no name for a given clause).
}

> (compatible-closure <reduction-relation> <lang> <non-terminal>) SYNTAX

This accepts a reduction, a language, the name of a
non-terminal in the language and returns the compatible
closure of the reduction for the specified non-terminal.

> (context-closure <reduction-relation> <lang> <pattern>) SYNTAX

This accepts a reduction, a language, a pattern representing
a context (ie, that can be used as the first argument to
`in-hole'; often just a non-terminal) in the language and
returns the closure of the reduction in that context.

> (define-metafunction name <language-exp>
     [<pattern> <rhs-expression> (side-condition <exp>) ...] ...)     SYNTAX

The `define-metafunction' form builds a function on
sexpressions according to the pattern and right-hand-side
expressions. The first argument indicates the language used
to resolve non-terminals in the pattern expressions. Each of
the rhs-expressions is implicitly wrapped in `term'. In
addition, recursive calls in the right-hand side of the
metafunction clauses should appear inside `term'. 

If specified, the side-conditions are collected with an
`and' and used as guards on the case being matched. The
argument to each side-condition should be a Scheme
expression, and the pattern variables in the <pattern> are
bound in that expression.

As an example, this metafunction finds the free variables in
an expression in the lc-lang above:

  ;; free-vars : e -> (listof x)
  (define-metafunction free-vars
    lc-lang
    [(e_1 e_2 ...) 
     ,(apply append (term ((free-vars e_1) (free-vars e_2) ...)))]
    [x_1 ,(list (term x_1))]
    [(lambda (x_1 ...) e_1)
     ,(foldr remq (term (free-vars e_1)) (term (x_1 ...)))])

The first argument to define-metafunction is the grammar
(defined above). Following that are three cases, one for
each variation of expressions (e in lc-lang). The right-hand
side of each clause begins with a comma, since they are
implicitly wrapped in `term'. The free variables of an
application are the free variables of each of the subterms;
the free variables of a variable is just the variable
itself, and the free variables of a lambda expression are
the free variables of the body, minus the bound parameters.

> (define-metafunction/extension name <language-exp> extending-name
     [<pattern> <rhs-expression> (side-condition <exp>) ...] ...)     SYNTAX   

This defines a metafunction as an extension of an existing
one. The extended metafunction behaves as if the original
patterns were in this definitions, with the name of the
function fixed up so that recursive functions behave as expected.

> (define-multi-args-metafunction name <language-exp>
     [<pattern> <rhs-expression> (side-condition <exp>) ...] ...)     SYNTAX

Like define-metafunction, this defines a
metafunction. Unlike it, this defines a metafunction that
accepts multiple arguments. 

There are two significant differences:

  - patterns match the entire argument list, rather than just
    matching the single argument
  - the typesetting for define-multi-args-metafunction uses
    commas to separate the arguments in the definition
    and at the callsites. 

> (define-multi-arg-metafunction/extension name <language-exp> extending-name
     [<pattern> <rhs-expression> (side-condition <exp>) ...] ...)     SYNTAX   

Like define-metafunction/extension, this defines a
metafunction as an extension of an existing one, but this
time for multi-argument metafunctions.

> (in-domain? <term> <metafunction-name>)

Returns #t if <term> is in the domain of the specified
metafunction. 

If the metafunction is defined with define-metafunction,
then the term representing the argument should appear
exactly as it appears in a call to the metafunction.

If the metafunction is defined with
define-multi-args-metafunction, then the arguments should
be parenthesized.

> (test-equal e1 e2)                            SYNTAX

Tests to see if e1 is equal to e2.

> (test--> reduction-relation e1 e2 ...)        SYNTAX

Tests to see if the value of e1 (which should be a term),
reduces to the e2s.

> (test-predicate p? e)                         SYNTAX

Tests to see if the value of `e' matches the predicate p?.

> test-results :: (-> void?)

Prints out how many tests passed and failed, and resets the
counters so that next time this function is called, it
prints the test results for the next round of tests.

> plug :: (any? any? . -> . any)

The first argument to this function is an sexpression to
plug into. The second argument is the sexpression to replace
in the first argument. It returns the replaced term. This is
also used when a `term' sub-expression contains `in-hole'.

> apply-reduction-relation :: (reduction-relation? any? . -> . (listof any?))

Reduce accepts a list of reductions, a term, and returns a
list of terms that the term reduces to.

> apply-reduction-relation/tag-with-names ::
  (-> reduction-relation? 
      any/c
      (listof (list/c (union false/c string?) any/c)))

Like apply-reduction-relation, but the result indicates the
names of the reductions that were used.

> apply-reduction-relation* ::
   (reduction-relation? any? . -> . (listof (listof any?))

apply-reduction-relation* accepts a list of reductions and a
term. It returns the results of following every reduction
path from the term. If there are infinite reduction
sequences starting at the term, this function will not
terminate.

> (redex-match lang pattern any)                  SYNTAX

Matches the pattern (in the language) against the third
expression. If it matches, this returns a list of match
structures describing the matches. If it fails, it returns
#f.

> (redex-match lang pattern)                      SYNTAX

Builds a procedure for efficiently testing if expressions
match the pattern `pattern' in the language `lang'. The
procedures accepts a single expression and if the expresion
matches, it returns a list of match structures describing the
matches. If the match fails, the procedure returns #f.

> match? :: (any/c . -> . boolean?)

Determines if a value is a mtch structure.

> match-bindings :: (mtch? -> (listof bind?))

This returns a bindings structure (see below) that
binds the pattern variables in this match.

> variable-not-in :: (any? symbol? . -> . symbol?)

This helper function accepts an sexpression and a
variable. It returns a variable not in the sexpression with
a prefix the same as the second argument.

> variables-not-in :: (any? (listof symbol?) . -> . (listof symbol?))

This function, like variable-not-in, makes variables that do
no occur in its first argument, but it returns a list of
such variables, one for each variable in its second
argument. 

Does not expect the input symbols to be distinct, but does
produce variables that are always distinct.

> make-bind :: (symbol? any? . -> . bind?)
> bind? :: (any? . -> . boolean?)
> bind-name :: (bind? . -> . symbol?)
> bind-exp :: (bind? . -> . any?)

Constructor, predicate, and selector functions for the rib
values contained within a bindings (returned by redex-match).
Each rib associates a name with an s-expression from the
language, or a list of such s-expressions, if the (name ...)
clause is followed by an ellipsis.  Nested ellipses produce
nested lists.

> set-cache-size! :: (union #f positive-integer) -> void

Changes the cache size; a #f disables the cache
entirely. The default size is 350.

The cache is per-pattern (ie, each pattern has a cache of
size at most 350 (by default)) and is a simple table that
maps expressions to how they matched the pattern. When the
cache gets full, it is thrown away and a new cache is
started.

_Debugging PLT Redex Programs_

It is easy to write grammars and reduction rules that are
subtly wrong and typically such mistakes result in examples
that just get stuck when viewed in a `traces' window.

The best way to debug such programs is to find an expression
that looks like it should reduce but doesn't and try to find
out what pattern is failing to match. To do so, use the
redex-match special form, described above.

In particular, first ceck to see if the term matches the
main non-terminal for your system (typically the expression
or program nonterminal). If it does not, try to narrow down
the expression to find which part of the term is failing to
match and this will hopefully help you find the problem. If
it does match, figure out which reduction rule should have
matched, presumably by inspecting the term. Once you have
that, extract a pattern from the left-hand side of the
reduction rule and do the same procedure until you find a
small example that shoudl work but doesn't (but this time
you might also try simplifying the pattern as well as
simplifying the expression).


======================================================================

The _gui.ss_ library provides the following functions:

> (stepper reductions expr [pp]) ::
    (opt-> (compiled-lang?
            reduction-relation?
            any/c)
           ((or/c (any -> string)
                  (any output-port number (is-a?/c text%) -> void)))
           void?)

This function opens a stepper window for exploring the
behavior of its third argument in the reduction system
described by its first two arguments. 

The pp function is used to specially print expressions. It
must either accept one or four arguments. If it accepts one
argument, it will be passed each term and is expected to
return a string to display the term.

If the pp function takes four arguments, it should render
its first argument into the port (its second argument) with
width at most given by the number (its third argument). The
final argument is the text where the port is connected --
characters written to the port go to the end of the editor.

The default pp, provided as default-pretty-printer, uses
MzLib's pretty-print function. See threads.ss in the
examples directory for an example use of the one-argument
form of this argument and ho-contracts.ss in the examples
directory for an example use of its four-argument form.

> (stepper/seed reductions seed [pp]) ::
    (opt-> (compiled-lang?
            reduction-relation?
            (cons/c any/c (listof any/c)))
           ((or/c (any -> string)
                  (any output-port number (is-a?/c text%) -> void)))
           void?)

Like `stepper', this function opens a stepper window, but it
seeds it with the reduction-sequence supplied in `terms'.

> (traces reductions expr 
          #:pred [pred (lambda (x) #t)]
          #:pp [pp default-pretty-printer] 
          #:colors [colors '()]
          #:multiple? [multiple? #f])
  lang : language
  reductions : (listof reduction)
  expr : (or/c (listof sexp) sexp)
  multiple : boolean  --- controls interpretation of expr
  pred : (or/c (sexp -> any)
               (sexp term-node? any))
  pp : (or/c (any -> string)
             (any output-port number (is-a?/c text%) -> void))
  colors : (listof (list string string))

This function opens a new window and inserts each expression
in expr (if multiple is #t -- if multiple is #f, then expr
is treated as a single expression). Then, it reduces the
terms until either reduction-steps-cutoff (see below)
different terms are found, or no more reductions can
occur. It inserts each new term into the gui. Clicking the
`reduce' button reduces until reduction-steps-cutoff more
terms are found.

The pred function indicates if a term has a particular
property. If it returns #f, the term is displayed with a
pink background. If it returns a string or a color% object,
the term is displayed with a background of that color (using
the-color-database<%> to map the string to a color). If it
returns any other value, the term is displayed normally. If
the pred function accepts two arguments, a term-node
corresponding to the term is passed to the predicate. This
lets the predicate function explore the (names of the)
reductions that led to this term, using term-node-children,
term-node-parents, and term-node-labels.

The pred function may be called more than once per node. In
particular, it is called each time an edge is added to a
node. The latest value returned determines the color.

The pp argument is the same as to the stepper functions
(above).

The colors argument, if provided, specifies a list of
reduction-name/color-string pairs. The traces gui will color
arrows drawn because of the given reduction name with the
given color instead of using the default color.

You can save the contents of the window as a postscript file
from the menus.

> term-node-children :: (-> term-node (listof term-node))

Returns a list of the children (ie, terms that this term
reduces to) of the given node.

Note that this function does not return all terms that this
term reduces to -- only those that are currently in the
graph.

> term-node-parents :: (-> term-node (listof term-node))

Returns a list of the parents (ie, terms that reduced to the
current term) of the given node.

Note that this function does not return all terms that
reduce to this one -- only those that are currently in the
graph.

> term-node-labels :: (-> term-node (listof (union false/c string)))

Returns a list of the names of the reductions that led to
the given node, in the same order as the result of
term-node-parents. If the list contains #f, that means that
the corresponding step does not have a label.

> term-node-set-color! :: 
   (-> term-node? 
       (or/c string? (is-a?/c color%) false/c)
       void?)

Changes the highlighting of the node; if its second argument
is #f, the coloring is removed, otherwise the color is set
to the specified color% object or the color named by the
string. The color-database<%> is used to convert the string
to a color% object.

> term-node-set-red! :: (-> term-node boolean void?)

Changes the highlighting of the node; if its second argument
is #t, the term is colored pink, if it is #f, the term is
not colored specially.

> term-node-expr :: (-> term-node any)

Returns the expression in this node.

> term-node? :: (-> any boolean)

Recognizes term nodes.

> (reduction-steps-cutoff)
> (reduction-steps-cutoff number)

A parameter that controls how many steps the `traces' function
takes before stopping.

> (initial-font-size)
> (initial-font-size number)

A parameter that controls the initial font size for the terms shown
in the GUI window.

> (initial-char-width)
> (initial-char-width number)

A parameter that determines the initial width of the boxes
where terms are displayed (measured in characters) for both
the stepper and traces.

> (dark-pen-color color-or-string)
> (dark-pen-color) => color-or-string

> (dark-brush-color color-or-string)
> (dark-brush-color) => color-or-string

> (light-pen-color color-or-string)
> (light-pen-color) => color-or-string

> (light-brush-color color-or-string)
> (light-brush-color) => color-or-string

These four parameters control the color of the edges in the graph.

======================================================================

The _pict.ss_ library provides functions designed to
automatically typeset grammars, reduction relations, and
metafunction written with plt redex. 

Each grammar, reduction relation, and metafunction can be
saved in a .ps file (as encapsulated postscript), or can be
turned into a pict. 

Picts are more useful for debugging since DrScheme REPL will
show you the pict directly (albeit with slightly different
fonts than you'd see in the .ps file). You can also use the
picts with Slideshow's pict library to build more complex
arrangements of the figures and add other picts. See
Slideshow for details.

If you are only using the picts to experiment in DrScheme's
REPL, be sure your program is in the GUI library, and
contains this header:

  #lang scheme/gui
  (require texpict/mrpict)
  (dc-for-text-size (make-object bitmap-dc% (make-object bitmap% 1 1)))

Be sure to remove the call to dc-for-text-size before you
generate .ps files, otherwise the font spacing will be wrong
in the .ps file.

> language->pict ::
  (->* (compiled-lang? 
        (or/c false/c (cons/c symbol? (listof symbol?))))
       ((or/c false/c (cons/c symbol? (listof symbol?))))
      pict?)

> language->ps ::
  (->* (compiled-lang?
        (or/c path? string?))
       ((or/c false/c (cons/c symbol? (listof symbol?))))
       void?)

These two functions turn a languages into picts. The first
argument is the language, and the second is a list of
non-terminals that should appear in the pict. It may only
contain symbols that are in the language's set of
non-terminals.

For language->ps, the path argument is a filename for the
PostScript file.

> extend-language-show-union : (parameter/c boolean?)

If this is #t, then a language constructed with
extend-language is shown as if the language had been
constructed directly with `language'. If it is #f, then only
the last extension to the language is shown (with
four-period ellipses, just like in the concrete syntax).

Defaultly #f.

Note that the #t variant can look a little bit strange if
.... are used and the original version of the language has
multi-line right-hand sides.

> reduction-relation->pict :: 
    (opt-> (reduction-relation?)
           ((or/c false/c (listof (union string? symbol?))))
           pict?)

> reduction-relation->ps ::
    (opt-> (reduction-relation?
            (union string? path?))
           ((or/c false/c (listof (union string? symbol?))))
           void?)

These two functions turn reduction relations into picts.

The optional lists determine which reduction rules are shown
in the pict.

> (metafunction->pict metafunction-name) -> pict
> (metafunction->ps metafunction-name (union path? string?)) -> void

These two syntactic forms turn metafunctions into picts

There are also customization parameters:

> rule-pict-style :: 
  (parameter/c (symbols 'vertical 
                        'compact-vertical
                        'vertical-overlapping-side-conditions
                        'horizontal))

This parameter controls the style used for the reduction
relation. It can be either horizontal, where the left and
right-hand sides of the reduction rule are beside each other
or vertical, where the left and right-hand sides of the
reduction rule are above each other. The vertical mode also
has a variant where the side-conditions don't contribute to
the width of the pict, but are just overlaid on the second
line of each rule.

> arrow-space :: (parameter/c natural-number/c)

This parameter controls the amount of extra horizontal space
around the reduction relation arrow. Defaults to 0.

> horizontal-label-space :: (parameter/c natural-number/c)

This parameter controls the amount of extra space before the
label on each rule, but only in horizontal mode. Defaults to
0.

> metafunction-pict-style :: 
  (parameter/c (symbols 'left-right 'up-down))

This parameter controls the style used for typesetting
metafunctions. The 'left-right style means that the
results of calling the metafunction are displayed to the 
right of the arguments and the 'up-down style means that
the results are displayed below the arguments.

> label-style :: (parameter/c text-style/c)
> literal-style :: (parameter/c text-style/c)
> metafunction-style :: (parameter/c text-style/c)
> non-terminal-style :: (parameter/c text-style/c)
> non-terminal-subscript-style :: (parameter/c text-style/c)
> default-style :: (parameter/c text-style/c)

These parameters determine the font used for various text in
the picts. See `text' in the texpict collection for
documentation explaining text-style/c. One of the more
useful things it can be is one of the symbols 'roman,
'swiss, or 'modern, which are a serif, sans-serif, and
monospaced font, respectively. (It can also encode style
information, too.)

The label-style is used for the reduction rule label
names. The literal-style is used for names that aren't
non-terminals that appear in patterns. The
metafunction-style is used for the names of
metafunctions. The non-terminal-style is for non-terminals
and non-terminal-subscript-style is used for the portion
after the underscore in non-terminal references.

The default-style is used for parenthesis, the dot in dotted
lists, spaces, the separator words in the grammar, the
"where" and "fresh" in side-conditions, and other places
where the other parameters aren't used.

> label-font-size :: (parameter/c (and/c (between/c 1 255) integer?))
> metafunction-font-size :: (parameter/c (and/c (between/c 1 255) integer?))
> default-font-size :: (parameter/c (and/c (between/c 1 255) integer?))

These parameters control the various font sizes. The
default-font-size is used for all of the font sizes except
labels and metafunctions.

> reduction-relation-rule-separation :: 
  (parameter/c (and/c integer? positive? exact?))  

Controls the amount of space between clauses in a reduction
relation. Defaults to 4.

> curly-quotes-for-strings :: (parameter/c boolean?)

Controls if the open and close quotes for strings are turned
into “ and ” or are left as merely ".

Defaults to #t.

> current-text :: (parameter/c (-> string? text-style/c number? pict?))

This parameter's function is called whenever Redex typesets
some part of a grammar, reduction relation, or
metafunction. It defaults to mrpict.ss's `text' function.

> set-arrow-pict! :: (-> symbol? (-> pict?) void?)

This functions sets the pict for a given reduction-relation
symbol. When typesetting a reduction relation that uses the
symbol, the thunk will be invoked to get a pict to render
it. The thunk may be invoked multiple times when rendering a
single reduction relation.

============================================================

_Removing the pink background from PLT Redex rendered picts and ps files_
_Rewriting patterns during typesetting for PLT Redex_

When reduction rules, a metafunction, or a grammar contains
unquoted Scheme code or side-conditions, they are rendered
with a pink background as a guide to help find them and
provide alternative typesettings for them. In general, a
good goal for a PLT Redex program that you intend to typeset
is to only include such things when they correspond to
standard mathematical operations, and the Scheme code is an
implementation of those operations.

To replace the pink code, use:

> (with-unquote-rewriter proc expression)

It installs `proc' the current unqoute rewriter and
evaluates expression. If that expression computes any picts,
the unquote rewriter specified is used to remap them.

The 'proc' should be a function of one argument. It receives
a lw struct as an argument and should return
another lw that contains a rewritten version of the
code.

> (with-atomic-rewriter name-symbol string-or-thunk-returning-pict expression)

This extends the current set of atomic-rewriters with one
new one that rewrites the value of name-symbol to
string-or-pict-returning-thunk (applied, in the case of a
thunk), during the evaluation of expression.

name-symbol is expected to evaluate to a symbol. The value
of string-or-thunk-returning-pict is used whever the symbol
appears in a pattern.

> (with-compound-rewriter name-symbol proc expression)

This extends the current set of compound-rewriters with one
new one that rewrites the value of name-symbol via proc,
during the evaluation of expression.

name-symbol is expected to evaluate to a symbol. The value
of proc is called with a (listof lw) -- see below
for details on the shape of lw, and is expected to
return a new (listof (union lw string pict)),
rewritten appropriately. 

The list passed to the rewriter corresponds to the
lw for the sequence that has name-symbol's value at
its head.

The result list is constrained to have at most 2 adjacent
non-lws. That list is then transformed by adding
lw structs for each of the non-lws in the
list (see the description of lw below for an
explanation of logical-space):

 0: If there are two adjacent lws, then the logical
    space between them is filled with whitespace.

 1: If there is a pair of lws with just a single
    non-lw between them, a lw will be
    created (containing the non-lw) that uses all
    of the available logical space between the lws.

 2: If there are two adjacent non-lws between two
    lws, the first non-lw is rendered
    right after the first lw with a logical space
    of zero, and the second is rendered right before the
    last lw also with a logical space of zero, and
    the logical space between the two lws is
    absorbed by a new lw that renders using no
    actual space in the typeset version.

============================================================

The lw data structure corresponds represents a
pattern or a Scheme expression that is to be typeset. 

A _lw_ is a struct:
  (build-lw element posnum posnum posnum posnum)
with selectors:
>  lw-e :: lw -> element
>  lw-line :: lw -> posnum
>  lw-line-span :: lw -> posnum
>  lw-column :: lw -> posnum
>  lw-column-span :: lw -> posnum

An _element_ is either:
  string
  symbol
  pict
  (listof lw)

Each sub-expression corresponds to its own lw, and
the element indicates what kind of subexpression it is. If
the element is a list, then the lw corresponds to a
parenthesized sequence, and the list contains a lw
for the open paren, one lw for each component of the
sequence and then a lw for the close
parenthesis. In the case of a dotted list, there will also
be a lw in the third-to-last position for the dot.

For example, this expression:

  (a)

becomes this lw (assuming the above expression
appears as the first thing in the file):

     (build-lw (list (build-lw "(" 0 0 0 1)
                              (build-lw 'a 0 0 1 1)
                              (build-lw ")" 0 0 2 1))
                        0 0 0 3)

If there is some whitespace in the sequence, like this one:

  (a b)

then there is no lw that corresponds to that
whitespace; instead there is a logical gap between the
lws.

     (build-lw (list (build-lw "(" 0 0 0 1)
                     (build-lw 'a 0 0 1 1)
                     (build-lw 'b 0 0 3 1)
                     (build-lw ")" 0 0 4 1))
               0 0 0 5)

In general, identifiers are represented with symbols and
parenthesis are represented with strings and picts can be
inserted to render arbitrary pictures.

The line, line-span, column, and column-span correspond to
the logical spacing for the redex program, not the actual
spacing that will be used when they are rendered. The
logical spacing is only used when determining where to place
typeset portions of the program. In the absense of any
rewriters, these numbers correspond to the line and column
numbers in the original program.

The line and column are absolute numbers from the beginning
of the file containing the expression. The column number is
not necessarily the column of the open parenthesis in a
sequence -- it is the leftmost column that is occupied by
anything in the sequence. The line-span is the number of
lines, and the column span is the number of columns on the
last line (not the total width).

When there are multiple lines, lines are aligned based on
the logical space (ie, the line/column &
line-span/column-span) fields of the lws. As an
example, if this is the original pattern:

   (all good boys
        deserve fudge)

then the leftmost edges of the words "good" and "deserve"
will be lined up underneath each other, but the relative
positions of "boys" and "fudge" will be determined by the
natural size of the words as they rendered in the
appropriate font.

There are two helper functions that make building
lws easier:

> just-before :: (-> (or/c pict? string? symbol?) 
                     lw?
                     lw?)
> just-after :: (-> (or/c pict? string? symbol?) 
                    lw?
                    lw?)

These functions build new lws whose contents are
the first argument, and whose line and column are based on
the second argument, making the new loc wrapper be either
just before or just after that argument. The line-span and
column-span of the new lw is always zero.

> (to-lw arg)                               SYNTAX

This form turns its argument into lw structs that
contain all of the spacing information just as it would appear
when being used to typeset.

======================================================================

The _iswim.ss_ module in the "examples" sub-collection defines a
grammar and reductions from "Programming Languages and Lambda Calculi"
by Felleisen and Flatt.

       Example S-expression forms of ISWIM expressions:
         Book                     S-expr
         ----                     ------
         (lambda x . x)           ("lam" x x)
         (+ '1` '2`)              ("+" 1 2)
         ((lambda y y) '7`)       (("lam" y y) 7)

       CK machine:
         Book                     S-expr
         ----                     ------
         <(lambda x . x), mt>     (("lam" x x) : "mt")

       CEK machine:
         Book                     S-expr
         ----                     ------
         <<(lambda x . x),        ((("lam" x x)
           {<X,<5,{}>>}>,           : ((X (5 : ()))))
          mt>                      : "mt")
         
       The full grammar:

         (language (M (M M)
                      (o1 M)
                      (o2 M M)
                      V)
                   (V X
                      ("lam" variable M)
                      b)
                   (X variable)
                   (b number)
                   (o1 "add1" "sub1" "iszero")
                   (o2 "+" "-" "*" "^")
                   (on o1 o2)
                   
                   ;; Evaluation contexts:
                   (E hole
                      (E M)
                      (V E)
                      (o1 E)
                      (o2 E M)
                      (o2 V E))
     
                   ;; Continuations (CK machine):
                   (k "mt"
                      ("fun" V k)
                      ("arg" M k)
                      ("narg" (V ... on) (M ...) k))
     
                   ;; Environments and closures (CEK):
                   (env ((X = vcl) ...))
                   (cl (M : env))
                   (vcl (V- : env))
                   
                   ;; Values that are not variables:
                   (V- ("lam" variable M)
                       b)
     
                   ;; Continuations with closures (CEK);
                   (k- "mt"
                       ("fun" vcl k-)
                       ("arg" cl k-)
                       ("narg" (vcl ... on) (cl ...) k-)))
     
       The following are provided by "iswim.ss":

               Grammar and substitution:
>                 iswim-grammar :: compiled-lang?
>                 M? :: (any? . -> . boolean?)
>                 V? :: (any? . -> . boolean?)
>                 o1? :: (any? . -> . boolean?)
>                 o2? :: (any? . -> . boolean?)
>                 on? :: (any? . -> . boolean?)
>                 k? :: (any? . -> . boolean?)
>                 env? :: (any? . -> . boolean?)
>                 cl? :: (any? . -> . boolean?)
>                 vcl? :: (any? . -> . boolean?)
>                 k-? :: (any? . -> . boolean?)
>                 iswim-subst :: (M? symbol? M? . -> . M?)
>                 empty-env :: env?
>                 env-extend :: (env? symbol? vcl? . -> . env?)
>                 env-lookup :: (env? symbol? . -> . (union false? vcl?))
               Reductions:
>                 beta_v :: reduction-relation?
>                 delta :: reduction-relation?
>                 ->v :: reduction-relation?
>                 :->v :: reduction-relation?
               Abbreviations:
>                 if0 :: (M? M? M? . -> . M?)
>                 true :: M?
>                 false :: M?
>                 mkpair :: M?
>                 fst :: M?
>                 snd :: M?
>                 Y_v :: M?
>                 sum :: M?
               Helpers:
>                 delta*1 :: (o1? V? . -> . (union false? V?))
                     delta as a function for unary operations.
>                 delta*2 :: (o2? V? V? . -> . (union false? V?))
                     delta as a function for binary operations.
>                 delta*n :: (on? (listof V?) . -> . (union false? V?))
                     delta as a function for any operation.



@index-section[]

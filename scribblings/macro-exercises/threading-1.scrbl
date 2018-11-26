#lang scribble/manual

@(require (for-label racket/base
                     racket/contract)
          racket/format
          scribble/example
          "util.rkt")

@(module threading-ids racket/base
   (require (for-label threading)
            scribble/manual)
   (provide threading:~>)
   (define threading:~> @racket[~>]))
@(require 'threading-ids)

@title[#:tag "threading-1"]{Threading I}

Clojure includes a useful macro, which it calls @racketplainfont{->}. This macro is known as the
“threading” macro because it “threads” a value through a series of expressions. You may also find it
useful to compare it to a shell pipeline. For example, in Clojure:

@(examples
  #:label #f
  #:escape unsyntax
  (eval:alts (@#,racketplainfont{->} 5 (@#,racketplainfont{*} 2) (@#,racketplainfont{+} 1))
             (+ (* 5 2) 1)))

The precise details of how that works will be elaborated upon in a moment, but notice how the first
expression, @racket[5], is first multiplied by two, then incremented by one to produce @racket[11].

@margin-note{
  This macro is available in Racket via the @racketmodname[threading] package. The “real” version of
  @threading:~> is more featureful than the version you will implement here, but future exercises will
  expand upon this simplified version.}

In Racket, the name @racket[->] is already used by @racketmodname[racket/contract], so the threading
macro in Racket is usually named @racket[~>] instead. We will use this name for our threading macro.

@section[#:tag "threading-1-specification"]{Specification}

The @racket[~>] macro is used to convert a nested expression into a more readable “flattened”
pipeline. For example, this expression:

@racketblock[(- (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1) 2)]

Can be written in “pipeline” style like this:

@racketblock[(~> 'abc
                 symbol->string
                 string->bytes/utf-8
                 (bytes-ref 1)
                 (- 2))]

The following three rules specify how the above transformation works.

@defrule["threading-1" 1] For any expression @racket[_x], @racket[(~> _x)] is equivalent to
@racket[_x]. That is, when @racket[~>] only has a single subform, it expands to the subform directly,
with no modifications.

@(examples
  (eval:alts (~> 'hello) 'hello)
  (eval:alts (~> (+ 1 2)) (+ 1 2))
  (eval:alts (~> (let ([x 12])
                   (* x 3)))
             (let ([x 12])
               (* x 3))))

This forms the “base case” of the @racket[~>] macro. Successive application of the other rules will
eventually produce an expression of the form @racket[(~> _x)].

@defrule["threading-1" 2] For any expression @racket[(_f _a #,ooo)] (where @racket[_f] should evaluate
to a function and each @racket[_a] should evaluate to a function argument),
@racket[(~> _x (_f _a #,ooo) _more #,ooo)] is equivalent to
@racket[(~> (_f _x _a #,ooo) _more #,ooo)].

For example, @racket[(~> 5 (+ 1))] expands to @racket[(~> (+ 5 1))].

Note that the above example allows an additional sequence of @racket[_more] subforms, which are passed
through unchanged. That is, @racket[(~> 5 (+ 1) (* 2))] expands into @racket[(~> (+ 5 1) (* 2))],
which in turn expands into @racket[(~> (* (+ 5 1) 2))], finally producing @racket[(* (+ 5 1) 2)] due
to @rule["threading-1" 1].

Here are some evaluation examples that include expansion steps to help better understand how this rule
works:

@(examples
  #:label #f
  #:eval ((make-eval-factory '(racket)))
  #:once
  (eval:alts (~> "hello, "
                 (string-append "world"))
             (begin (displayln @~a{expansion steps:
                                     1. (~> (string-append "hello, " "world"))
                                     2. (string-append "hello, " "world")})
                    (string-append "hello, " "world")))
  (eval:alts (~> #\a
                 (list #\z)
                 (list->string))
             (begin (displayln @~a{expansion steps:
                                     1. (~> (list #\a #\z)
                                            (list->string))
                                     2. (~> (list->string (list #\a #\z))
                                     3. (list->string (list #\a #\z))})
                    (list->string (list #\a #\z))))
  (eval:alts (~> 'abc
                 (symbol->string)
                 (string->bytes/utf-8)
                 (bytes-ref 1)
                 (- 2))
             (begin (displayln @~a{expansion steps:
                                     1. (~> (symbol->string 'abc)
                                            (string->bytes/utf-8)
                                            (bytes-ref 1)
                                            (- 2))
                                     2. (~> (string->bytes/utf-8 (symbol->string 'abc))
                                            (bytes-ref 1)
                                            (- 2))
                                     3. (~> (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1)
                                            (- 2))
                                     4. (~> (- (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1) 2))
                                     5. (- (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1) 2)})
                    (- (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1) 2))))

@defrule["threading-1" 3] For any identifier @racket[_id], @racket[(~> _x _id _more #,ooo)] is
equivalent to @racket[(~> _x (_id) _more #,ooo)].

For example, @racket[(~> 'abc symbol->string)] expands to @racket[(~> 'abc (symbol->string))].

Put another way, this rule just wraps bare identifiers in parentheses---it is a convienience rule that
allows users to omit parentheses. Every expansion of this rule will be followed by an expansion of
@rule["threading-1" 2].

@(examples
  (eval:alts (~> #\a
                 (list #\z)
                 list->string)
             (list->string (list #\a #\z)))
  (eval:alts (~> 'abc
                 symbol->string
                 string->bytes/utf-8
                 (bytes-ref 1)
                 (- 2))
             (- (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1) 2)))

@section[#:tag "threading-1-grammar"]{Grammar}

This section describes the expected grammar for the @racket[~>] macro without specifying
functionality.

@(defform #:link-target? #f (~> val-expr clause ...)
   #:grammar ([clause (fn-expr arg-expr ...)
                      bare-id]))

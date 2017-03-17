#lang scribble/manual

@(require (for-label racket/base
                     racket/contract)
          racket/format
          scribble/example)

@(module threading-ids racket/base
   (require (for-label threading)
            scribble/manual)
   (provide threading:~>)
   (define threading:~> @racket[~>]))
@(require 'threading-ids)

@(define ooo @racketplainfont{...})

@title[#:tag "threading-1"]{Threading I}

Clojure includes a useful macro, which it calls @racketplainfont{->}. This macro is known as the
“threading” macro because it “threads” a value through a series of expressions. You may also find it
useful to compare it to a shell pipeline. For example, in Clojure:

@(examples
  #:label #f
  #:escape unsyntax
  (eval:alts (@#,racketplainfont{->} 5 (@#,racketplainfont{*} 2) (@#,racketplainfont{+} 1))
             (+ (* 5 2) 1)))

The precise details of how that works will be elaborated in a moment, but you can see how the first
expression, @racket[5], is first multiplied by two, then incremented by one to produce @racket[11].

@margin-note{
  This macro is available in Racket via the @racketmodname[threading] package. The “real” version of
  @threading:~> is somewhat more complex than the version you will implement here, but future
  exercises will expand upon this simplified version.}

In Racket, the name @racket[->] is already used by @racketmodname[racket/contract], so the threading
macro in Racket is usually named @racket[~>] instead. We will use this name to implement our threading
macro.

@section[#:tag "threading-1-specification"]{Specification}

The @racket[~>] macro is used to convert a complex, nested expression into a simpler, “flattened”
pipeline. For example, this expression:

@racketblock[(- (bytes-ref (string->bytes/utf-8 (symbol->string 'abc)) 1) 2)]

Can be written in “pipeline” style like this:

@racketblock[(~> 'abc
                 symbol->string
                 string->bytes/utf-8
                 (bytes-ref 1)
                 (- 2))]

The following specification includes three rules that elaborate how the above transformation works.

@bold{Rule 1.} For any expression @racket[_x], @racket[(~> _x)] is identical to @racket[_x]. That is,
when @racket[~>] only has a single subform, it expands to the subform with no modifications.

@(examples
  (eval:alts (~> 'hello) 'hello)
  (eval:alts (~> (+ 1 2)) (+ 1 2))
  (eval:alts (~> (let ([x 12])
                   (* x 3)))
             (let ([x 12])
               (* x 3))))

This will form the “base case” of the @racket[~>] macro. Other rules will eventually expand into
the form @racket[(~> _x)].

@bold{Rule 2.} For any expression @racket[(_f _a #,ooo)], where @racket[_f] is a function and each
@racket[_a] is a function argument, @racket[(~> _x (_f _a #,ooo) _more #,ooo)] is equivalent to
@racket[(~> (_f _x _a #,ooo) _more #,ooo)].

For example, @racket[(~> 5 (+ 1))] expands to @racket[(~> (+ 5 1))].

Note that the above example allows an additional sequence of @racket[_more] subforms, which are passed
through unchanged. That is, @racket[(~> 5 (+ 1) (* 2))] expands into @racket[(~> (+ 5 1) (* 2))],
which in turn expands into @racket[(~> (* (+ 5 1) 2))], finally producing @racket[(* (+ 5 1) 2)] due
to Rule 1.

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

@bold{Rule 3.} For any identifier @racket[_id], @racket[(~> _x _id _more #,ooo)] is equivalent to
@racket[(~> _x (_id) _more #,ooo)].

For example, @racket[(~> 'abc symbol->string)] expands to @racket[(~> 'abc (symbol->string))].
Essentially, this rule wraps just bare identifiers in parentheses.

This rule is a simple convienience rule that allows users to omit parentheses where unnecessary. Every
expansion of this rule will be followed by an expansion of Rule 2.

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

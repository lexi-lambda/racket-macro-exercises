#lang scribble/manual

@(require (for-label racket/base)
          scribble/example
          "util.rkt")

@title[#:tag "threading-2"]{Threading II}

In @secref{threading-1}, you created a @racket[~>] macro that threads values through functions.
However, it was fairly limited in capability. One major limitation was that it always threaded values
into the @emph{first} argument position. That is, @racket[(~> _x (_f _y _z))] always produces
@racket[(_f _x _y _z)], with @racket[_x] right at the beginning of the argument list.

This works alright a lot of the time, but sometimes, it isn’t enough: not all functions have the
“interesting” argument in the first position, and what’s “interesting” might change depending on what
you’re doing. Take, for example, the following expression:

@(racketblock
  (- (apply + (map add1 '(1 2 3))) 1))

This expression is nested, which can be confusing to read, and converting it to a pipeline could make
it much clearer. Unfortunately, we @emph{cannot} use our @racket[~>] macro to simplify it, since if we
wrote

@(racketblock
  (~> '(1 2 3)
      (map add1)
      (apply +)
      (- 1)))

we would find the arguments end up in the wrong positions. The above expression would actually be
equivalent to this:

@(racketblock
  (- (apply (map '(1 2 3) add1) +) 1))

This is wrong, since it attempts to run @racket[(map '(1 2 3) add1)], which is nonsensical---we cannot
apply a list as a function! The problem with our existing @racket[~>] macro is that @racket[map] and
@racket[apply] expect their “interesting” arguments at the @emph{end} of the argument list, instead of
at the beginning.

It might be tempting to create an alternative macro that’s just like @racket[~>] but threads into the
final position instead of the first, but that wouldn’t work either, since @racket[(- 1)] needs the
argument threaded into the first position. What we really want is to be able to control the threading
position as necessary, overriding the default on a case-by-case basis.

To do this, we will introduce a “hole marker”, @racket[_], which can explicitly indicate the location
of the threaded expression. It’s probably easiest to illustrate with an example:

@(racketblock
  (~> '(1 2 3)
      (map add1 _)
      (apply + _)
      (- _ 1)))

The @racket[~>] macro will recognize the hole marker specially, and it will adjust the threading
position based on its location, producing the original, correct expression.

@section[#:tag "threading-2-specification"]{Specification}

Our new @racket[~>] macro will work exactly the same as the old one, except that we will introduce an
additional rule, which takes priority over the other rules:

@defrule["threading-2" 4] For any function @racket[_f] and arguments @racket[_a #,ooo] and
@racket[_b #,ooo], @racket[(~> _x (_f _a #,ooo _ _b #,ooo) more #,ooo)] is equivalent to
@racket[(~> (_f _a #,ooo _x _b #,ooo) more #,ooo)].

For example, @racket[(~> 1 (list-ref '(10 20) _))] expands to @racket[(~> (list-ref '(10 20)) 1)] and
@racket[(~> 2 (substring "hello, world" _ 6))] expands to
@racket[(~> (substring "hello, world" 2 6))].

@(examples
  (eval:alts (~> 1 (list-ref '(10 20) _))
             (list-ref '(10 20) 1))
  (eval:alts (~> 2 (substring "hello, world" _ 6))
             (substring "hello, world" 2 6))
  (eval:alts (~> '(1 2 3)
                 (map add1 _)
                 (apply + _)
                 (- 1))
             (- (apply + (map add1 '(1 2 3))) 1)))

@section[#:tag "threading-2-grammar"]{Grammar}

@defform[
 #:link-target? #f
 #:literals [_]
 (~> val-expr clause ...)
 #:grammar ([clause (fn-expr pre-expr ... _ post-expr ...)
                    (fn-expr arg-expr ...)
                    bare-id])]

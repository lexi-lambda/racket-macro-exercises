#lang scribble/manual

@(require (for-label racket/base)
          scribble/example)

@(define ooo @racketplainfont{...})

@title[#:tag "threading-2"]{Threading II}

In @secref{threading-1}, you created a @racket[~>] macro that threads values through functions.
However, it was fairly limited in capability. One major limitation was that it always threaded values
into the @emph{first} argument position. That is, @racket[(~> _x (_f _y _z))] always produces
@racket[(_f _x _y _z)], with @racket[_x] right at the beginning of the argument list.

This works alright a lot of the time, but sometimes, it isn’t enough. Not all functions have the most
“interesting” argument in the first position, and sometimes, what’s “interesting” might change
depending on what you’re doing. Take, for example, the following expression:

@(racketblock
  (- (apply + (map add1 '(1 2 3))) 1))

This expression is nested, which can be confusing to read, but it’s also actually a fairly simple
pipeline. Unfortunately, we @emph{cannot} use our @racket[~>] macro to simplify it, since if we did
this:

@(racketblock
  (~> '(1 2 3)
      (map add1)
      (apply +)
      (- 1)))

…we would end up with the arguments in the wrong positions. The above expression would actually be
equivalent to this:

@(racketblock
  (- (apply (map '(1 2 3) add1) +) 1))

This is obviously pretty wrong, since it attempts to run @racket[(map '(1 2 3) add1)], which is
blatantly incorrect. Instead, @racket[map] and @racket[apply] expect their arguments at the @emph{end}
instead of the beginning.

We could create an alternative macro that’s just like @racket[~>] but threads into the final position,
but that wouldn’t work for this case, either, since @racket[(- 1)] needs the argument threaded into
the first position. What we really want to be able to do is control the threading position as
necessary, overriding the default on a case-by-case basis.

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

@bold{Rule 4.} For any function @racket[_f] and arguments @racket[_a #,ooo] and @racket[_b #,ooo],
@racket[(~> _x (_f _a #,ooo _ _b #,ooo) more #,ooo)] is equivalent to
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

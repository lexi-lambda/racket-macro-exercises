#lang scribble/manual

@(require (for-label racket/base
                     syntax/parse/define)
          scribble/example)

@(define (reftech . pre-content)
   (apply tech #:doc '(lib "scribblings/reference/reference.scrbl") pre-content))

@title[#:tag "exhaustive-enumerations"]{Exhaustive Enumerations}

@margin-note{
  Inspiration for this exercise comes from an example from Robby Findler’s talk @italic{Racket: a
  programming-language programming language}.}

A concept available in many programming languages is the notion of @deftech{enumerations}, a value
with a known set of discrete possibilities. An enumeration might be used to represent the days of the
week, a set of well-known colors, different blending modes, or all sorts of other things.

In Racket, ordinary Racket @reftech{symbols} are often used for this purpose. For example, one might
represent a day of the week using the symbols @racket['sunday], @racket['monday], @racket['tuesday],
etc. It’s possible to use Racket’s @racket[case] form to perform branching on symbols, so we could use
it to write a function that checks if a day of the week is a weekend or not:

@(racketblock
  (define (weekend? day)
    (case day
      [(saturday sunday) #t]
      [(monday tuesday wednesday thursday friday) #f])))

For the purposes of this exercise, we’ll use a simpler, sillier example: an enumeration of animals,
@racket['cat], @racket['dog], and @racket['cow]. We could write a function that accepts an animal and
produces a string corresponding to the sound it makes. It might look like this:

@(examples
  #:label #f
  (eval:no-prompt
   (define (animal-sound x)
     (case x
       [(cat) "meow"]
       [(dog) "woof"]
       [(cow) "moo"])))

  (eval:check (animal-sound 'cat) "meow")
  (eval:check (animal-sound 'dog) "woof"))

However, what if we subsequently wanted to make our program support a new kind of animal, such as
@racket['fish]? Well, we could just add a new case to our @racket[animal-sound] function, like this:

@(racketblock
  (define (animal-sound x)
    (case x
      [(cat) "meow"]
      [(dog) "woof"]
      [(cow) "moo"]
      [(fish) "glub"])))

But there’s a problem. What if you use animals all over your program, and you forget to add the new
@racket['fish] case in just one of them? Oops. That’s probably a bug. Wouldn’t it be great if
@racket[case] knew which possible values can be in our enumeration, and it would warn us if we forgot
to handle one of them?

To make this possible, we can write two macros, @racket[define-enum] and @racket[enum-case], which
will @emph{work together} to ensure at compile-time all values are handled:

@(examples
  #:label #f
  (eval:alts
   (define-enum animal
     [cat dog cow fish])
   (void))
  (eval:alts
   (define (animal-sound x)
     (enum-case animal x
       [(cat) "meow"]
       [(dog) "woof"]
       [(cow) "moo"]))
   (eval:result '() "" "enum-case: missing case for 'fish"))
  (eval:alts
   (define (animal-sound x)
     (enum-case animal x
       [(cat) "meow"]
       [(dog) "woof"]
       [(cow) "moo"]
       [(fish) "glub"]))
   (define (animal-sound x)
     (case x
       [(cat) "meow"]
       [(dog) "woof"]
       [(cow) "moo"]
       [(fish) "glub"])))
  (eval:check (animal-sound 'fish) "glub"))

Ensuring that call cases are handled is known as @deftech{exhaustiveness checking}.

@section[#:tag "exhaustive-enumerations-implementation-strategy"]{Implementation strategy}

How is it possible to implement @racket[define-enum] and @racket[enum-case], given that they need to
somehow communicate with each other at compile-time? And what does @racket[define-enum] even define?

The key to solving is problem is a special function, @racket[syntax-local-value], which provides a
mechanism for compile-time cooperation between macros. Specifically, it makes it possible for a macro
to get at the @emph{value} of a definition defined with @racket[define-syntax]. Normally, we use
@racket[define-syntax] to define a macro by creating a syntax binding with a procedure of one argument
as its value, but this isn’t actually necessary. We can use @racket[define-syntax] to define anything
at all:

@(define local-value-eval (make-base-eval '(require (for-syntax racket/base)
                                                    syntax/parse/define)))

@(examples
  #:label #f
  #:eval local-value-eval
  (define-syntax x 3))

What does this actually do? Well, on its own, not very much. We can’t use @racket[x] as an expression,
since it raises a compile-time error:

@(examples
  #:label #f
  #:eval local-value-eval
  (eval:error x))

However, we @emph{can} use @racket[syntax-local-value] to retrieve the value of @racket[x] inside a
macro.

@(examples
  #:label #f
  #:eval local-value-eval
  #:escape UNSYNTAX
  (eval:alts
   (define-syntax (quote-x stx)
     #`((UNSYNTAX @racket[quote]) #,(syntax-local-value #'x)))
   (define-syntax (quote-x stx)
     #`(quote #,(syntax-local-value #'x))))
  (eval:check (quote-x) 3))

Of course, this alone isn’t very useful. It becomes especially interesting, however, when we use
@racket[syntax-local-value] on an identifier provided to the macro as a subform:

@(examples
  #:label #f
  #:eval local-value-eval
  (eval:alts
   (define-simple-macro (quote-local-value i:id)
     #:with val (syntax-local-value #'i)
     (@#,racket[quote] val))
   (define-simple-macro (quote-local-value i:id)
     #:with val (syntax-local-value #'i)
     (quote val)))
  (quote-local-value x))

@(close-eval local-value-eval)

This trick can be used to allow @racket[define-enum] and @racket[enum-case] to indirectly communicate.
@racket[define-enum] can expand into a use of @racket[define-syntax] that binds the name of the
enumeration to a @reftech{set} of valid symbols at compile-time, and @racket[enum-case] can use
@racket[syntax-local-value] on the provided enumeration name to inspect which symbols should be
covered.

@section[#:tag "exhaustive-enumerations-specification"]{Specification}

The expected behavior of @racket[define-enum] and @racket[enum-case] is defined in terms of how they
should work together. A definition of the shape
@racket[(define-enum enum-id [case-id @#,racketidfont{...}])] does not do anything at all on its own,
but it should define @racket[enum-id] in such a way that it can be used with @racket[enum-case].

The @racket[enum-case] form should function equivalently to @racket[case], except that it should be
provided the name of an enumeration, and it should perform @tech{exhaustiveness checking} at
compile-time based on the possible cases of the enumeration.

Here are two sample enumerations defined with @racket[define-enum]:

@(racketblock
  (define-enum day-of-week
    [sunday monday tuesday wednesday thursday friday saturday])
  (define-enum animal
    [cat dog cow fish]))

Assuming the above enumeration definitions, both of the following definitions should be valid:

@(racketblock
  (define (weekend? day)
    (enum-case day-of-week day
      [(saturday sunday) #t]
      [(monday tuesday wednesday thursday friday saturday) #f]))
  (define (animal-sound x)
    (enum-case animal x
      [(cat) "meow"]
      [(dog) "woof"]
      [(cow) "moo"]
      [(fish) "glub"])))

The above definitions should produce the following results when called:

@(examples
  #:label #f
  (eval:alts (weekend? 'wednesday) #f)
  (eval:alts (weekend? 'sunday) #t)
  (eval:alts (animal-sound 'dog) "woof"))

Both of the following definitions should be invalid, and they should fail to compile with error
messages similar to the following:

@(examples
  #:label #f
  (eval:alts
   (define (weekend? day)
     (enum-case day-of-week day
       [(saturday sunday) #t]
       [(monday friday) #f]))
   (eval:result '() "" "enum-case: missing cases for 'tuesday, 'wednesday, and 'thursday"))
  (eval:alts
   (define (animal-sound x)
    (enum-case animal x
      [(cat kitten) "meow"]
      [(dog puppy) "woof"]
      [(cow) "moo"]
      [(fish) "glub"]))
   (eval:result '() "" "enum-case: 'kitten and 'puppy are not valid cases for animal")))

@section[#:tag "exhaustive-enumerations-grammar"]{Grammar}

@defform[#:link-target? #f
         (define-enum enum-id
           [case-id ...])]

@defform[#:link-target? #f
         (enum-case enum-id val-expr
           [(case-id @#,racketidfont{...+}) body-expr @#,racketidfont{...+}] ...)]

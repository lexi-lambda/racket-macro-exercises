#lang scribble/manual

@(require (for-label racket/base
                     racket/file
                     racket/format
                     racket/match)
          scribble/example)

@(define (reftech . pre-content)
   (apply tech #:doc '(lib "scribblings/reference/reference.scrbl") pre-content))
@(define (refref key)
   @secref[key #:doc '(lib "scribblings/reference/reference.scrbl")])

@title[#:tag "string-match"]{String Match}

@margin-note{
  Thanks to Daniel Prager for coming up with this problem on the
  @hyperlink["https://groups.google.com/d/msg/racket-users/OXwXdmzAbf8/aLBBFsY2EgAJ"]{Racket mailing
  list}.}

Sometimes, especially for scripting or solving coding puzzles, it can be useful to have tools for
parsing strings in a particular format. Regular expressions can serve that purpose, but they can be
difficult to read, especially when capture groups are involved.

It could be convenient to have a @racket[string-match] form that’s able to parse simple, common cases
without having the complexity (or power) of full regular expressions. For example, we might wish to
parse lines with the following structure:

@filebox[
 "favorite-numbers.txt"
 @nested[#:style 'code-inset]{@verbatim{
  10:Alice:a nice, round number
  16:Bob:a round number in base 2
  42:Douglas:the ultimate answer}}]

Using a special @racket[string-match] form, we could parse them like this:

@(examples #:label #f
  (eval:no-prompt
   (define (parse-line str)
     (string-match str
       [(n ":" name ":" description)
        (list (string->number n)
              name
              description)])))
  (eval:alts (map parse-line (file->lines "favorite-numbers.txt"))
             '((10 "Alice" "a nice, round number")
               (16 "Bob" "a round number in base 2")
               (42 "Douglas" "the ultimate answer"))))

A slightly more complex example might involve small sentences with a simple, predefined structure:

@filebox[
 "statements.txt"
 @nested[#:style 'code-inset]{@verbatim{
   The sky is blue.
   My car is red.
   The heat death of the universe is inevitable.}}]

We could use @racket[string-match] to parse these sorts of structures, too:

@(examples #:label #f
  (eval:no-prompt
   (define (parse-sentence str)
     (string-match str
       [("The " noun " is " adjective ".")
        `(statement ,noun ,adjective)]
       [("My " noun " is " adjective ".")
        `(possessive-statement ,noun ,adjective)])))
  (eval:alts (map parse-sentence (file->lines "sentences.txt"))
             '((statement "sky" "blue")
               (possessive-statement "car" "red")
               (statement "heat death of the universe" "inevitable"))))

In this exercise, you will implement @racket[string-match].

@section[#:tag "string-match-implementation-strategy"]{Implementation strategy}

How can we implement @racket[string-match]? It may seem like an involved macro, but fortunately, we
don’t have to implement it from scratch. Racket’s macro system is compositional, so we can assemble
most of it out of existing parts already provided by the standard library.

With this in mind, consider what @racket[string-match] actually does. From a high level, it performs
two distinct tasks:

@nested[
 #:style 'inset
 @itemlist[
  #:style 'ordered
  @item{It matches strings against a particular pattern…}
  @item{…then binds matched substrings to variables.}]]

Each of these goals can be accomplished using existing Racket features. For the first part, we can use
@reftech{regular expressions} by @emph{compiling} our patterns to regular expressions at compile-time.
For the second part, we can use @racket[match] from @racketmodname[racket/match], which conveniently
already supports matching strings against regular expressions.

@subsection[#:tag "string-match-regexps-and-syntax"]{Regular expressions and syntax}

How can we compile our @racket[string-match] patterns to regular expressions? Well, Racket supports
regular expression literals, written like @racket[#rx""] or @racket[#px""]. For more information on
the precise syntax, see @refref{parse-regexp}.

For our purposes, however, the exact details of the syntax don’t matter. What’s important is that
Racket supports regular expression literals, which means regular expressions are valid syntax objects!
For proof, try syntax-quoting a regular expression literal:

@(examples #:label #f
  #'#rx"[a-z]+")

We can exploit this property to embed regular expressions in the output of a macro. To create these
regular expressions in the first place, we can produce them from strings using the @racket[regexp]
function:

@(examples #:label #f
  (regexp "[a-z]+"))

We can also use @racket[regexp-quote] to safely embed constant strings inside a regular expression
without worrying about escaping special characters:

@(examples #:label #f
  (regexp (string-append (regexp-quote "+?[") "[^\\]]+" (regexp-quote "]?+"))))

Finally, we can use @racket[datum->syntax] to convert a dynamically-constructed regular expression
into a regular expression literal that can be embedded in syntax:

@(examples #:label #f
  (datum->syntax #'here (regexp (string-append "hello" "-" "world"))))

Using this technique, we can use @racket[regexp], @racket[regexp-quote], and @racket[datum->syntax] to
compile our @racket[string-match] patterns into fast, efficient regexps.

@subsection[#:tag "string-match-pattern-matching"]{Pattern-matching with @racketmodname[racket/match]}

Racket’s @racket[match] form is useful for all sorts of pattern-matching, including pattern-matching
against regexps. For example, it’s possible to parse a simple URL using the following @racket[match]
expression:

@(examples #:label #f #:once #:eval ((make-eval-factory '(racket/match)))
  (match "http://example.com/foobar"
    [(regexp #rx"^([^:]+)://([^/]+)/(.+)$" (list _ protocol hostname path))
     (list protocol hostname path)]))

You can read the @racket[match] documentation for the full syntax, but the most relevant piece for our
@racket[string-match] macro is the @racket[(regexp _rx _pat)] pattern, where @racket[_rx] is a regular
expression and @racket[_pat] is a pattern that will be matched against the results of the regexp
match.

The syntax for @racket[match] is a little different from our @racket[string-match], since it uses
regular expressions instead of inline sequences of strings and bindings. Still, it’s pretty close, and
combined with the previous section on regular expressions, you may be able to see how to combine the
two to produce an efficient implementation of @racket[string-match].

@section[#:tag "string-match-specification"]{Specification}

With the explanations out of the way, it’s now time to implement @racket[string-match]. Your task is
to implement a simple, greedy string-matching macro that is efficiently compiled to regular
expressions.

Here is an example use of @racket[string-match]:

@(racketblock
  (define (sm str)
    (string-match str
      [(a "--" b " " c " end") (list (string->symbol a) (string->number b) c)]
      [("the " object " is " adjective) (~a adjective " " object)] 
      [("whole-string") 'whole])))

You can see that @racket[string-match] looks remarkably like @racket[match]. The only difference is
the pattern syntax, which is composed of a sequence of strings and identifiers. Each pattern should be
compiled into a regular expression by embedding string literals directly into the result using
@racket[regexp-quote], and identifiers should become capture groups of zero or more characters,
@racketvalfont{(.*)}.

To illustrate the above rules, that example should roughly expand into the following code:

@(racketblock
  (define (sm str)
    (match str
      [(regexp #rx"^(.*)--(.*) (.*) end$" (list _ a b c))
       (list (string->symbol a) (string->number b) c)]
      [(regexp #rx"^the (.*) is (.*)$" (list _ object adjective))
       (~a adjective " " object)]
      [(regexp #rx"^whole-string$" (list _))
       'whole])))

The defined function, @racket[sm], should produce the following results when applied to input:

@(examples #:label #f
  (eval:alts (sm "abc--123 foo end")
             '(abc 123 "foo"))
  (eval:alts (sm "the fox is black")
             "black fox")
  (eval:alts (sm "whole-string")
             'whole)
  (eval:alts (sm "abc--123--456 bar end")
             '(abc--123 456 "bar")))

@section[#:tag "string-match-grammar"]{Grammar}

@defform[#:link-target? #f
         (string-match str-expr
           [(str-pat ...+) body-expr ...+] ...)
         #:grammar ([str-pat string-literal
                             binding-id])
         #:contracts ([str-expr string?])]

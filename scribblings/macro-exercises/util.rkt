#lang at-exp racket/base

(require racket/contract
         racket/format
         scribble/core
         scribble/manual)

(provide (contract-out [defrule (-> string? exact-nonnegative-integer? element?)]
                       [rule (-> string? exact-nonnegative-integer? element?)])
         ooo)

(define ooo @racketplainfont{...})

(define (make-rule-tag prefix n)
  (~a prefix "-rule-" n))
(define (defrule prefix n)
  @elemtag[(make-rule-tag prefix n)]{@bold{Rule @~a[n].}})
(define (rule prefix n)
  @elemref[(make-rule-tag prefix n) #:underline? #f]{Rule @~a[n]})

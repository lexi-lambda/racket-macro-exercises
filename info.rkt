#lang info

(define collection 'multi)

(define deps
  '())
(define build-deps
  '("base"
    "racket-doc"
    ["scribble-lib" #:version "1.16"]
    "threading-doc"
    "threading-lib"))
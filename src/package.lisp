(defpackage #:rag-backend-memory
  (:use #:cl)
  (:export #:memory-vector-store
           #:make-memory-vector-store
           #:use-memory-vector-store
           #:memory-store-dimension))

(in-package #:rag-backend-memory)

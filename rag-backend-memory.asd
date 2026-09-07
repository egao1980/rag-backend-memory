(defsystem "rag-backend-memory"
  :version "0.1.0"
  :description "In-process cosine vector store for rag-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("rag-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "rag-backend-memory/tests"))))

(defsystem "rag-backend-memory/tests"
  :depends-on ("rag-backend-memory" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))

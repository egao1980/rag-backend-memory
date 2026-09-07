(in-package #:rag-backend-memory/tests)

(defun %vec (&rest xs)
  (map 'vector (lambda (x) (float x 1f0)) xs))

(defun %chunk (id text emb)
  (rag-protocol:make-rag-chunk :id id :document-id "d" :text text :embedding emb))

(deftest use-memory-binds
  (let ((rag-protocol:*rag-store* nil))
    (rag-backend-memory:use-memory-vector-store)
    (ok (typep rag-protocol:*rag-store* 'rag-backend-memory:memory-vector-store))))

(deftest upsert-query-ranks
  (let ((store (rag-backend-memory:make-memory-vector-store)))
    (rag-protocol:upsert store
                         (list (%chunk "a" "alpha" (%vec 1 0))
                               (%chunk "b" "beta" (%vec 0 1))))
    (let ((hits (rag-protocol:query-store store (%vec 1 0) :top-k 2)))
      (ok (= 2 (length hits)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits)))))
      (ok (> (rag-protocol:rag-hit-score (first hits))
             (rag-protocol:rag-hit-score (second hits)))))))

(deftest replace-same-id
  (let ((store (rag-backend-memory:make-memory-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "old" (%vec 1 0)))
    (rag-protocol:upsert store (%chunk "a" "new" (%vec 0 1)))
    (let ((hits (rag-protocol:query-store store (%vec 0 1) :top-k 1)))
      (ok (equal "new" (rag-protocol:rag-chunk-text
                        (rag-protocol:rag-hit-chunk (first hits))))))))

(deftest delete-and-missing
  (let ((store (rag-backend-memory:make-memory-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (ok (equal '("a") (rag-protocol:delete-ids store '("a"))))
    (ok (signals (rag-protocol:delete-ids store "a")
                 'rag-protocol:rag-not-found))))

(deftest dimension-mismatch
  (let ((store (rag-backend-memory:make-memory-vector-store)))
    (rag-protocol:upsert store (%chunk "a" "x" (%vec 1 0)))
    (ok (signals (rag-protocol:upsert store (%chunk "b" "y" (%vec 1 0 0)))
                 'rag-protocol:rag-dimension-mismatch))
    (ok (signals (rag-protocol:query-store store (%vec 1 0 0) :top-k 1)
                 'rag-protocol:rag-dimension-mismatch))))

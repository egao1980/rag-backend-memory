(in-package #:rag-backend-memory)

(defclass memory-vector-store (rag-protocol:rag-vector-store)
  ((chunks :initform (make-hash-table :test 'equal) :accessor memory-store-table)
   (dimension :initarg :dimension :accessor memory-store-dimension :initform nil)))

(defun make-memory-vector-store (&key dimension)
  (make-instance 'memory-vector-store :dimension dimension))

(defun use-memory-vector-store (&rest args &key &allow-other-keys)
  (setf rag-protocol:*rag-store* (apply #'make-memory-vector-store args)))

(defun %as-list (x)
  (if (listp x) x (list x)))

(defun %accepted-embedding (store chunk)
  (let ((emb (rag-protocol:rag-chunk-embedding chunk)))
    (unless (and emb (plusp (length emb)))
      (error 'rag-protocol:rag-error
             :message (format nil "chunk ~s has no embedding"
                              (rag-protocol:rag-chunk-id chunk))))
    (tagbody
     :retry
       (let ((dim (length emb)))
         (cond
           ((null (memory-store-dimension store))
            (setf (memory-store-dimension store) dim)
            (return-from %accepted-embedding emb))
           ((= dim (memory-store-dimension store))
            (return-from %accepted-embedding emb))
           (t
            (restart-case
                (error 'rag-protocol:rag-dimension-mismatch
                       :expected (memory-store-dimension store)
                       :actual dim
                       :id (rag-protocol:rag-chunk-id chunk)
                       :message (format nil "chunk ~s: expected dim ~d, got ~d"
                                        (rag-protocol:rag-chunk-id chunk)
                                        (memory-store-dimension store)
                                        dim))
              (continue ()
                :report "Skip this chunk"
                (return-from %accepted-embedding nil))
              (use-value (value)
                :report "Use a supplied embedding vector"
                (setf emb value
                      (rag-protocol:rag-chunk-embedding chunk) value)
                (go :retry)))))))))

(defmethod rag-protocol:upsert ((store memory-vector-store) chunks)
  (dolist (ch (%as-list chunks))
    (when (%accepted-embedding store ch)
      (unless (rag-protocol:rag-chunk-id ch)
        (error 'rag-protocol:rag-error :message "chunk id required for upsert"))
      (setf (gethash (rag-protocol:rag-chunk-id ch) (memory-store-table store)) ch)))
  store)

(defmethod rag-protocol:delete-ids ((store memory-vector-store) ids)
  (let* ((ids (%as-list ids))
         (missing '())
         (deleted '()))
    (dolist (id ids)
      (if (nth-value 1 (gethash id (memory-store-table store)))
          (progn
            (remhash id (memory-store-table store))
            (push id deleted))
          (push id missing)))
    (setf missing (nreverse missing)
          deleted (nreverse deleted))
    (when missing
      (restart-case
          (error 'rag-protocol:rag-not-found
                 :ids missing
                 :message (format nil "unknown chunk ids: ~s" missing))
        (continue ()
          :report "Skip missing ids"
          (return-from rag-protocol:delete-ids deleted))
        (use-value (value)
          :report "Return a supplied value"
          (return-from rag-protocol:delete-ids value))))
    deleted))

(defmethod rag-protocol:query-store ((store memory-vector-store) query &key top-k filter)
  (let ((vec (rag-protocol:query-vector query))
        (hits '()))
    (when (and (memory-store-dimension store)
               (/= (length vec) (memory-store-dimension store)))
      (error 'rag-protocol:rag-dimension-mismatch
             :expected (memory-store-dimension store)
             :actual (length vec)
             :message (format nil "query dim ~d, store dim ~d"
                              (length vec) (memory-store-dimension store))))
    (maphash (lambda (id chunk)
               (declare (ignore id))
               (when (or (null filter) (funcall filter chunk))
                 (push (rag-protocol:make-rag-hit
                        :chunk chunk
                        :score (rag-protocol:cosine-similarity
                                vec (rag-protocol:rag-chunk-embedding chunk)))
                       hits)))
             (memory-store-table store))
    (rag-protocol:rerank (rag-protocol:make-identity-reranker)
                         query hits :top-k (or top-k 5))))

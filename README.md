# rag-backend-memory

In-process cosine vector store for [`rag-protocol`](https://github.com/egao1980/rag-protocol). Not the protocol — product backends stay in their own repos.

```lisp
(asdf:load-system "rag-backend-memory")
(rag-backend-memory:use-memory-vector-store)

(stack-rag:upsert stack-rag:*rag-store*
                  (stack-rag:make-rag-chunk
                   :id "a" :text "alpha"
                   :embedding #(1.0 0.0)))
(stack-rag:query-store stack-rag:*rag-store* #(1.0 0.0) :top-k 5)
```

Brute-force over a hash table. Fine for tests and small corpora. Dimension is fixed on first upsert; mismatches signal `rag-dimension-mismatch` (`continue` skips, `use-value` supplies a vector).

Part of [cl-stack](https://github.com/egao1980/cl-stack). Cookbook: [rag.md](https://github.com/egao1980/cl-stack/blob/main/docs/cookbooks/rag.md).

## License

MIT — see [LICENSE](LICENSE).

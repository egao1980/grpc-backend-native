# grpc-backend-native

[`egao1980/grpc`](https://github.com/egao1980/grpc) (qitab/grpc + native overlay) backend for [`grpc-protocol`](https://github.com/egao1980/grpc-protocol).

Part of [cl-stack](https://github.com/egao1980/cl-stack) agent-wire ([brief](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/grpc.md)).

```lisp
(asdf:load-system "grpc-backend-native")

(let ((ch (grpc-protocol:grpc-connect "localhost:50051" :credentials :insecure)))
  (unwind-protect
       (grpc-protocol:grpc-call ch "/pkg.Svc/Ping" octets)
    (grpc-protocol:grpc-close ch)))
```

Wave-1 credentials: `:insecure` only. SSL is `:unimplemented`. Windows: overlay does not exist yet — connect signals `:unimplemented`.

Unary uses public `grpc:grpc-call`. Streams use the same CFFI call object (`start-grpc-call` / `send-message` / `receive-message`).

Do not load a workspace git checkout of `grpc` for consumers — install the GHCR overlay via cl-repo (`0.9-rc1` / highest tag).

CI: canned [`cl-repository`](https://github.com/egao1980/cl-repository) (`test-system.yml` / `setup-client` + `ci`). Deps from `ghcr.io/egao1980/cl-systems`.

## License

MIT

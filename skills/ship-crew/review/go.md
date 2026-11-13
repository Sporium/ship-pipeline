# Review pack — go

Detect: `go.mod` at the repository root or in a module directory; `*.go` files in the diff.

Applies on top of core.md; project rules still win. Check the `go` directive in `go.mod` first: several rules depend on the language version.

## Critical

1. **Money in a lossy or overflowing integer type.** Mechanism: amounts held in `float64`, or in `int32`/`int` on a 32-bit target, or multiplied (`qty * priceCents`, a percentage, currency conversion) without a range check wrap silently, since Go integer overflow does not panic. A negative or huge client value passes straight through. Correct: `int64` minor units or the project's decimal type, validation of bounds at the boundary, and overflow checks on multiplication of untrusted values. Also: `strconv.Atoi` results fed unchecked into amounts or limits.

## High

2. **Unchecked or shadowed error.** Mechanism: `result, _ := f()` or a bare `f()` that returns an error (`Close`, `Commit`, `Rollback`, `Write`, `Scan`, `Exec`); and `err` shadowing with `:=` in an inner scope (`if x { v, err := g() ... }`) so the outer `err` stays nil and the function returns success. Spot a `:=` that reintroduces `err` inside an `if`/`for` block whose result is not returned. Deferred `tx.Rollback()` ignoring its error is fine; an ignored `tx.Commit()` is not.
3. **Goroutine leak or fire-and-forget without cancellation.** Mechanism: `go func(){ ... }()` that blocks on a channel send/receive, a `time.Ticker`, or a network call with nothing that ends it when the request or parent is cancelled; unbuffered result channel with an early return on error, so the sender blocks forever. Correct: pass a `context.Context` and select on `ctx.Done()`, buffer the channel to the sender count or use `errgroup.WithContext`, `defer ticker.Stop()`, and wait for goroutines before returning. Find how the project manages background work (a group, a worker pool) first.
4. **Context not propagated to I/O.** Mechanism: `db.Query`, `db.Exec`, `http.NewRequest`, `http.Get` or a gRPC call made without the request's `ctx` (or with `context.Background()` inside a handler), so a cancelled or timed-out request keeps its DB connection and upstream call alive. Correct: `QueryContext`, `ExecContext`, `NewRequestWithContext`, and a deadline derived from the caller's context.
5. **`http.Client` without a timeout, or the default client.** Mechanism: `&http.Client{}`, `http.DefaultClient` and `http.Get` have no timeout, so one hung upstream pins goroutines and connections until the process is exhausted. Same for a server built with `http.ListenAndServe` and no `ReadHeaderTimeout`. Correct: set `Timeout` (or a per-request context deadline) and, for servers, a configured `http.Server`. Reuse one client; a new client per request also defeats connection pooling.
6. **Response body not closed or not drained.** Mechanism: after `http.Do`/`Get`, a missing `defer resp.Body.Close()` leaks the connection; an early return before the `defer` (placed before the `err` check, it nil-dereferences on error; placed after, it is correct). Not reading the body to EOF on reuse prevents connection reuse. Report where the body is closed on some paths only, or never.
7. **`sql.Rows` not closed, or `rows.Err()` unchecked.** Mechanism: a `Query` without `defer rows.Close()` holds a pooled connection on every early return, which exhausts the pool under load. After the `for rows.Next()` loop, `rows.Err()` must be checked; otherwise a mid-iteration network error returns a truncated result as if complete. `QueryRow().Scan` with `sql.ErrNoRows` treated as a generic failure (or ignored) is the same class.
8. **Concurrent map access.** Mechanism: a `map` read and written from several goroutines (a package-level cache, a struct field in a long-lived handler) without a mutex or `sync.Map` ends in `fatal error: concurrent map writes`, which cannot be recovered and kills the process. Spot a shared map mutated in a handler or goroutine. Correct: `sync.RWMutex` next to the map, or a single owner goroutine. Verify it is shared, not local to one call.
9. **Loop variable captured (Go before 1.22).** Mechanism: with `go.mod` below `go 1.22`, `for _, x := range xs { go func(){ use(x) }() }` or a closure/`defer`/pointer `&x` stored in a slice sees the last value in every iteration. Correct: pass as an argument or `x := x`. Report only after confirming the `go` directive; from 1.22 each iteration has its own variable.
10. **Nil interface versus nil pointer.** Mechanism: a function returning `error` (or another interface) that returns a typed nil pointer (`var e *MyErr; return e`) yields a non-nil interface, so `if err != nil` is true and the caller treats success as failure. Spot a function that declares a concrete error type in a variable and returns it. Correct: return a literal `nil` on the success path.
11. **`defer` inside a loop.** Mechanism: deferred calls run at function exit, not at the end of an iteration, so `defer f.Close()` or `defer rows.Close()` in a loop over files, connections or locks holds all of them open until the function returns (descriptor exhaustion, held mutex). Correct: move the body into a function, or close explicitly at the end of each iteration.

## Medium

12. **`time.Time` compared with `==`.** The comparison includes the location pointer and the monotonic clock reading, so equal instants compare false (a value from the DB versus `time.Now()`). Use `Equal`, `Before`, `After`; for map keys or DB round trips, normalise with `UTC()` and `Round(0)`.
13. **`panic` for expected failures in library or handler code**, or a goroutine started without a `recover` when a panic would take down the whole server; find the project's recovery middleware first.
14. **Error returned without context across a layer** (`return err` from the repository with no `%w` wrap, so the log cannot say which operation failed). Report only when the project wraps errors elsewhere and the caller needs `errors.Is` to keep working.

## Do not report

- `_ = x.Close()` on a read-only file or a response body after the data has been fully read; a deliberate discard of an error that cannot affect the result.
- Loop-variable capture when `go.mod` says 1.22 or higher.
- Missing `context` on code that runs once at startup, in a CLI `main`, or in tests.
- Unexported helper without a doc comment, getter/setter naming, receiver-name taste: linters' domain.
- `interface{}` versus `any`, or preferring generics, unless it causes a defect.
- Goroutines in `main` or tests that end with the process.

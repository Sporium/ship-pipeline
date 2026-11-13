# Review pack — php-laravel

Detect: `composer.json` requiring `laravel/framework` (also `symfony/*`, or a WordPress plugin/theme with `wp-content` paths); `artisan`, `app/Http/Controllers`, `routes/*.php`, `*.php` files in the diff.

Applies on top of core.md; project rules still win. Find the project's own base classes, traits and policies before judging a change against them.

## Critical

1. **Mass assignment of privileged fields.** Mechanism: `Model::create($request->all())`, `->fill($request->all())` or `->update($request->all())` on a model whose `$fillable` is missing, or whose `$guarded = []`, lets the client set `role`, `is_admin`, `balance`, `user_id` or `tenant_id`. Spot it in the diff: `all()`, `input()` without a key list, or a `$fillable` that gained a privileged column. Correct: `$request->validated()` (or `safe()->only([...])`) and a `$fillable` that excludes privileged columns, which are set explicitly in code.
2. **Missing authorization on a new controller action.** Mechanism: core rule 1 and 2 in Laravel terms. A new method with no `$this->authorize()`, `Gate::authorize`, `can:` middleware or Form Request `authorize()` that returns `true` unconditionally (the generated stub does). Check whether the controller or route group already applies a policy; a Form Request `authorize()` returning `true` on a write is a finding unless a middleware covers it.
3. **Public-disk upload of private or executable content.** Mechanism: `$file->store('x', 'public')` or `Storage::disk('public')` for documents, invoices or IDs makes them reachable by URL without auth; a client-chosen filename or extension (`getClientOriginalName()`, `getClientOriginalExtension()`) can land a `.php` file in a web-served directory. Correct: a private disk plus an authorized download route or a temporary URL, a generated name, and a validation rule on mime and size (`mimes`, `max`).

## High

4. **Route model binding without scoping.** Mechanism: `Route::get('/projects/{project}')` resolves any record by id; the controller then reads or writes it without checking ownership. Nested bindings need `->scopeBindings()` or a `{project:slug}` relation that goes through the parent, or an explicit policy. Verify that the policy or query actually constrains by the current user or tenant, not only that binding "works".
5. **Dispatch inside a transaction without afterCommit.** Mechanism: `DB::transaction(function () { ...; SendInvoice::dispatch($order); })` can run the worker before commit (the job loads a missing or old row) or after rollback. Correct: `->afterCommit()` on the job, `public $afterCommit = true`, `after_commit => true` on the queue connection, or dispatching after the closure returns. Same for `event()` with queued listeners and notifications. Check the project's queue config first; if `after_commit` is globally true, stay silent.
6. **Queued job serializing a model.** Mechanism: `SerializesModels` stores only the id and reloads on execution, so the job sees newer data than the one the dispatcher meant (a price, a status) and fails with `ModelNotFoundException` if the row was deleted meanwhile. Passing a snapshot (an array, DTO, or the specific values needed) is correct when the job must act on the state at dispatch time. Flag when the job's logic depends on a value that changes between dispatch and run, or when a deleted record must still be processed (`deleteWhenMissingModels`).
7. **env() outside config files.** Mechanism: after `php artisan config:cache`, `env()` called from app code returns `null`, so a feature or key silently disappears in production only. Correct: read it in `config/*.php` and use `config('x.y')` elsewhere. Spot a new `env(` in `app/`, `routes/`, `resources/` or `database/`.
8. **N+1 on a request path.** Mechanism: a relation accessed inside a loop, a Blade `@foreach`, or an API Resource (`$this->author->name`) over a collection loaded without `with()`. One query per row, so latency grows with page size. Correct: `with()`/`load()`/`withCount()`; check whether the project sets `Model::preventLazyLoading()` or `shouldBeStrict()`, which would already catch it in non-production only.
9. **Raw query with interpolation.** Mechanism: `DB::raw("... $x")`, `whereRaw("col = '$v'")`, `orderByRaw($request->sort)`, `selectRaw` or `DB::statement` with a concatenated variable. Column names for `orderBy` taken from the request are an injection and error vector too. Correct: bindings (`whereRaw('col = ?', [$v])`) and an allow-list of sortable columns.
10. **New request field without validation.** Mechanism: a new key read via `$request->input()`, `->get()` or `->query()` in a controller that has no Form Request rule for it, so type, length and existence are unchecked and a bad value reaches the DB or a service. Correct: add it to the Form Request `rules()`, with `exists:` or `Rule::in()` for ids and enums, and read it through `validated()`.
11. **Carbon mutability and timezone.** Mechanism: `$date->addDays(7)` on a `Carbon` (mutable) instance mutates the model attribute or a shared value that is reused afterwards (a deadline moves twice). `now()` compared against a date column without checking `app.timezone` versus the DB timezone gives off-by-hours windows; `Carbon::parse($input)` on a user string ignores the user's zone. Correct: `CarbonImmutable` (`Date::use`) or `->copy()`, and explicit timezones at the boundary.
12. **Sync listener doing slow or failing work in a request.** Mechanism: an event listener without `ShouldQueue` runs in the request, so a mail or HTTP call slows the response and an exception aborts the user's action after the data has been saved. Conversely, a queued listener that depends on request state (`auth()`, `request()`, session) runs without it. Check which one the listener is and whether its body fits.

## Medium

13. **Heavy logic in the model or controller instead of the project's service layer.** Only if the project has a clear layer (Actions, Services, Repositories) and the change bypasses it; name the existing class.
14. **`Model::all()` or an unbounded `get()` for a growing table.** Use `paginate()`, `cursor()` or `chunkById()`. Report only when the table is clearly large or user-generated.
15. **Missing `$casts` for a new column** (`decimal`, `datetime`, `array`, enum), so the app handles strings where it expects values, and money arrives as float.

## Do not report

- `$guarded = []` on a model that is never filled from request data (seeders, internal factories only).
- `env()` inside `config/*.php` files, or in `artisan` console bootstrap code that never runs under the config cache.
- Missing `authorize()` when a route-level `can:` middleware, a controller `authorizeResource`, or a global scope already covers it.
- Lazy loading in a console command or a one-row page, where the loop is bounded and small.
- `request()->all()` passed to a validator or to a Form Request, which is how validation is meant to be fed.
- Facade usage versus dependency injection: taste, not a failure mode.

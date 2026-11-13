# Review pack — python

Detect: `pyproject.toml`, `requirements*.txt`, `Pipfile` or `setup.py` listing django, fastapi, flask, celery, sqlalchemy or pydantic; `manage.py`, `settings.py`, `celery.py`; `*.py` files in the diff.

Applies on top of core.md; project rules still win. Find the project's own session, transaction and task helpers before judging a change.

## Critical

1. **Unsafe deserialization of untrusted data.** Mechanism: `pickle.loads`, `yaml.load` without `SafeLoader`, `marshal`, `jsonpickle` or Celery with `accept_content` including `pickle`, fed from a request, a cache shared with other writers, a queue or an uploaded file, gives remote code execution. Correct: JSON, `yaml.safe_load`, a schema (Pydantic) at the boundary. Verify where the bytes come from before reporting; data produced and read only by the same trusted process is not a finding.
2. **Django security settings weakened.** Mechanism: `DEBUG = True` outside a dev-only settings file (leaks settings and stack traces), `ALLOWED_HOSTS = ['*']` in production settings, a hardcoded `SECRET_KEY`, `@csrf_exempt` on a view that uses session cookie auth and changes state, `SESSION_COOKIE_SECURE`/`CSRF_COOKIE_SECURE` turned off. Check the diff against the project's settings split (base/dev/prod); report only values that reach production.
3. **Raw SQL or ORM escape hatch with interpolation.** Mechanism: `cursor.execute(f"... {x}")`, `.raw(f"...")`, `.extra(where=[...])`, `RawSQL`, `text(f"...")` in SQLAlchemy, `order_by(request.GET['sort'])`. Correct: placeholders (`%s` with a params list, `text(...).bindparams`) and an allow-list for column names.

## High

4. **Missing atomicity or row lock on read-modify-write.** Mechanism: `obj = Model.objects.get(...); obj.balance -= x; obj.save()` loses concurrent updates. Correct: `F()` expressions with `update()`, `select_for_update()` inside `transaction.atomic()` (a lock outside a transaction does nothing and raises in Django), or SQLAlchemy `with_for_update()`. Also: multi-row writes that must succeed together without `atomic()` (or `ATOMIC_REQUESTS` is off). Find which one the project uses.
5. **Task side effect before commit.** Mechanism: `task.delay(obj.id)` inside `atomic()` can run on a worker before commit and fail with `DoesNotExist`, or run for a rolled back change. Correct: `transaction.on_commit(lambda: task.delay(obj.id))`; in SQLAlchemy, enqueue after `commit()`.
6. **Celery task with ORM objects as arguments, or retry without idempotency.** Mechanism: model instances and sessions are not JSON serializable, or (with pickle) carry stale state; pass ids and reload inside the task. `autoretry_for`, `self.retry()` or `acks_late=True` re-run the whole body after partial success, repeating a charge, email or insert. Correct: an idempotency key or a status check at the top, a bounded `max_retries` with backoff, and effects recorded atomically with their marker.
7. **Blocking call inside `async def`.** Mechanism: in FastAPI/Starlette/aiohttp, a sync SQLAlchemy session, `requests`, `time.sleep`, a sync Django ORM call or a CPU-bound loop inside `async def` blocks the whole event loop, so every request stalls under load. Correct: a plain `def` endpoint (FastAPI runs it in a thread pool), an async driver/session, `run_in_threadpool`, or `asyncio.to_thread`. Check which DB driver the project uses before reporting.
8. **Response model exposing internal fields.** Mechanism: returning an ORM object or a Pydantic model that mirrors the table (`password_hash`, `is_staff`, `internal_notes`, other users' emails) without `response_model` / `response_model_exclude`, or a DRF `ModelSerializer` with `fields = '__all__'` or `exclude = [...]`; a new column then leaks by default. Correct: a dedicated output schema with an explicit field list. Input models should likewise forbid extra fields (`extra='forbid'`) when the endpoint writes them straight to the model.
9. **ORM N+1 and queryset evaluated in a loop.** Mechanism: attribute access on a foreign key or reverse relation per row in a loop, template, or serializer without `select_related` (FK/one-to-one) or `prefetch_related` (many); `len(qs)` or `if qs:` instead of `.count()` / `.exists()`; `qs.filter()` inside a loop that re-queries each iteration; SQLAlchemy lazy loads in a loop (use `selectinload`/`joinedload`). Report on request paths with a growing collection.
10. **Naive datetimes.** Mechanism: `datetime.now()`, `datetime.utcnow()` (deprecated, returns naive) stored or compared with aware values raises `TypeError` or shifts by the server's offset; with Django, `USE_TZ = False` or naive values saved into aware fields warn and misrecord. Correct: `timezone.now()` or `datetime.now(timezone.utc)`, and conversion to the user's zone at the edge only.
11. **Session lifecycle in SQLAlchemy.** Mechanism: a module-level or shared `Session` reused across requests or threads; objects used after `commit()` with `expire_on_commit=True` (a lazy refresh, or `DetachedInstanceError` after the session closed); a session opened and not closed on the error path; a transaction left open across an external HTTP call. Correct: one session per request/task through the project's dependency or context manager.
12. **Mutable default argument.** Mechanism: `def f(items=[])`, `def f(opts={})`, a dataclass field `x: list = []`, or a Django field `default=[]`/`default={}` shares one object across calls, so state leaks between requests. Correct: `None` plus creation inside, `field(default_factory=list)`, `default=list`.

## Medium

13. **Bare `except:` or `except Exception: pass` around DB or network code** that hides `KeyboardInterrupt`, programming errors, or an aborted transaction (in Django, continuing after an error inside `atomic()` raises `TransactionManagementError`).
14. **Business logic in views, routers or serializers** when the project has a services/use-case layer; name it.
15. **`logging` with f-strings of sensitive objects** (`logger.info(f"user={user}")`, request bodies), where `__str__` or `repr` may include PII; prefer lazy `%s` args and an explicit field list.

## Do not report

- `utils.py`, `type: ignore` or missing type hints; typing coverage is the project's call.
- `.all()` on a small, bounded lookup table, or `select_related` absent in an admin or management command.
- `datetime.now()` in code that is explicitly local-time only (a CLI printing to the user's terminal).
- `@csrf_exempt` on webhook endpoints that verify a signature, or on token-authenticated APIs with no cookie auth.
- `pickle` used for a local cache or file that the same process writes and reads inside a trusted boundary.
- Sync DB calls inside a plain `def` FastAPI endpoint; that is the supported pattern.

# PHP2Shell hardening configuration

Drop-in configuration for PHP 5.5.38 **with the PHP2Shell patch** (CVE-2026-109618, CVE-2026-109619). CI loads these files and checks them under PHP-FPM and Apache mod_php (`ci/fpm-test.sh`, `ci/apache-test.sh`).

**Configuration does not fix PHP2Shell.** On an unpatched PHP, a request can still corrupt memory when it hits `memory_limit` or `max_execution_time` at the wrong moment, and the same request can then run code on that state. No setting prevents that. The patch is the fix. These settings:

- shrink the unauthenticated attack surface (request parsing);
- shorten how long state can live in a worker;
- make the patch's process terminations visible in the logs;
- avoid settings the advisory warns against.

| File | Where |
|---|---|
| `zz-php2shell.ini` | `conf.d/` of every SAPI (FPM, apache2, CLI), so it loads last |
| `php-fpm-global.conf` | `[global]` section of `php-fpm.conf` |
| `php-fpm-pool.conf` | each pool section, e.g. `[www]` |
| `apache-mod_php.conf` | main Apache server configuration (`Include`) |

## php.ini (`zz-php2shell.ini`)

| Setting | Value | Why |
|---|---|---|
| `post_max_size`, `upload_max_filesize`, `max_file_uploads` | 8M, 8M, 20 (tune) | Bound what PHP parses before the application runs, which is the unauthenticated window. Keep `post_max_size` well below `memory_limit`. |
| `max_input_vars`, `max_input_nesting_level` | 1000, 16 | Bound the number of variables and nested arrays built from input. Deep nesting multiplies allocations; the default is 64. |
| `max_multipart_body_parts` | -1 | New with the patch: caps multipart parts (-1 means `max_input_vars + max_file_uploads`). |
| `max_input_time` | 30 | CPU-time limit for parsing the request (default: unlimited). With the patch, exceeding it terminates the worker. |
| `file_uploads` | Off, if unused | Removes the multipart parser entirely. |
| `session.upload_progress.enabled` | Off | Serializes the session during body parsing, before RINIT. The patch already forces it off. |
| `memory_limit`, `max_execution_time` | 128M, 30 (tune) | With the patch, reaching either terminates the worker cleanly. Keep both finite; never use `memory_limit = -1`. |
| `expose_php` | Off | Hides the `X-Powered-By: PHP/5.5.38` version banner. Version scanners such as php2shell-checker then report UNKNOWN. |
| `display_errors`, `log_errors` | Off, On | |

## PHP-FPM

| Setting | Value | Why |
|---|---|---|
| `pm.max_requests` | 500 | Recycles workers, so no state lives in one for long (CVE-2026-109619 is state leaking into the next request). |
| `request_terminate_timeout` | 60s | The master kills a request that outlives `max_execution_time`/`max_input_time`, e.g. one blocked in I/O, where PHP's CPU timer doesn't run. |
| `catch_workers_output` | yes | **Required for visibility.** The patch writes OOM and timeout errors to the worker's stderr; without this the only trace is `exited with code 1/124`. |
| `security.limit_extensions` | .php | Only execute `.php` files. |
| `php_admin_flag/value[...]` | | Enforce the request-parsing settings per pool, so `.user.ini` or `ini_set()` can't loosen them. |
| `emergency_restart_threshold`/`_interval` | 10 / 1m | Reload the master if workers die from SIGSEGV/SIGBUS. The patch's clean exits don't count. |
| `process_control_timeout` | 10s | Bounded shutdown on reload or stop. |

## Apache mod_php

| Setting | Value | Why |
|---|---|---|
| MPM | prefork | The patch terminates the process. Under a threaded MPM (worker/event with ZTS PHP) that also kills every other request in the process. |
| `MaxConnectionsPerChild` | 500 | Recycles children (Apache 2.2: `MaxRequestsPerChild`). |
| `LimitRequestBody` | 8388608 | Apache rejects larger bodies with 413 before PHP parses them. Keep in line with `post_max_size`. |
| `LimitRequestFields`, `LimitRequestFieldSize`, `LimitRequestLine`, `Timeout` | 100, 8190, 8190, 60 | Bound headers and slow requests. |
| `ServerTokens`, `ServerSignature` | Prod, Off | No version banners. |
| `php_admin_flag/value` | | Enforce the request-parsing settings so `.htaccess` can't loosen them. |

## Do not use

- **`RLIMIT_AS` / `RLIMIT_DATA` as a memory cap.** That includes Apache `RLimitMEM`, systemd `LimitAS=`/`LimitDATA=` on the php-fpm or httpd unit, and `ulimit -v`/`-d`. The advisory warns they reach the same vulnerable failure paths. Use `memory_limit`. A cgroup memory limit (systemd `MemoryMax=`) kills the whole process and is fine.
- **`memory_limit = -1`.**

## Emergency measures for hosts that cannot be patched yet

`pm.max_requests = 1` (FPM) or `MaxConnectionsPerChild 1` (Apache) gives every request a fresh process. Stale state then can't reach the next request, but the request that triggers the corruption is **not** protected, and every request costs a fork. Combine it with the request-parsing limits above, and patch as soon as possible.

## Operational impact (with the patch)

Workers and children now exit on `memory_limit` (exit code 1) and `max_execution_time` (exit code 124) instead of continuing. Expect more process restarts and some 502 / empty responses on slow or memory-heavy endpoints. Size `pm.max_children` and `MaxRequestWorkers` with headroom, and alert on frequent `exited with code 124` in the FPM log.

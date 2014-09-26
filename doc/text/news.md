# News

## 1.1.6: 2014-09-29 (planned)

 * Sort dump responses for stable test result.
 * Use `--ready-notify-fd` option to wait droonga-engine is ready.

## 1.1.5: 2014-05-29

 * Add `--timeout` option to work on slow environment such as Travis CI.
 * Support tmpfs at `/dev/shm`.
 * Use the environment variable `DROONGA_BASE_DIR`.

## 1.1.4: 2014-04-29

 * Supports more Groonga-compatible commands available at droonga-engine 1.0.2.

## 1.1.3: 2014-03-29

### Improvements

  * Supported merging custom `catalog.json` for each test.
  * Saved actual results on "not checked" cases.
  * Supported a new `omit` directive.
  * Supported a new `require-catalog-version` directive.

## 1.1.2: 2014-02-28

### Improvements

  * Supported `catalog.json` version2.
  * Simplified test result report a bit.

## 1.1.1: 2014-01-29

### Improvements

  * Improved error report. It is more readable.
  * Used all received responses from Droonga Engine instead of the
    first response. You can check too many responses case.
  * Supported `table_remove` command.
  * Supported `inReplyTo` field normalization in response.
  * Supported the latest droonga-client gem.

## 1.1.0: 2013-12-29

### Improvements

  * Renamed to `--base` option to `--base-path` because "base" is too general.
  * Removed "/suite/" from test suite name.
  * Added new line to results to suppress "No newline at end of file" warning
    from `diff` command.
  * Suppressed needless invalid JSON warning for output result. We can see it
    in diff output.
  * Made 10x times faster by sending requests in disabling logs
    asynchronously.
  * Made 2x times faster by using tmpfs if available.

## 1.0.0: 2013-11-29

The first release!!!

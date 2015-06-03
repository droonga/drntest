# News

## 1.3.0: 2015-06-29 (planned)

### Improvements

 * Supports configuration specific expected result and catalog.
   You can provide extra flies for your tests with specific configuration, like:
   - `(test name).expected.(config name)`
   - `(test name).catalog.json.(config name)`
 * Supports configuration specific tests.
   Tests named like `(test name).test.(config name)` are processed only when the configuration is used.
   However you don't need to give suffix for other related files.
   For example, all these combinations work correctly:
   - `(test name).test.(config name)`,
     `(test name).catalog.json.(config name)` and
     `(test name).expected.(config name)`
   - `(test name).test.(config name)`,
     `(test name).catalog.json` and
     `(test name).expected`

## 1.2.0: 2015-04-29

### Improvements

  * Supported new directives to activate/diactivate completion and validation of messages.
    * `#@enable_completion` and `#@disable_completion` controls completion of request messages.
      Required fields of request messages are automatically completed by default.
    * `#@enable_validation` and `#@disable_validation` controls validation of request messages.
      Messages are validated by default.
  * `#@subscribe-until` directive, for subscription type commands like `dump`.
    You can unsubscribe the next request following to the directive automatically with given timeout, like:
    `#@subscribe-until 10s`
  * A `NO RESPONSE` result is now returned immediately, for a stalled engine process.
  * Invalid format responses for Groonga commands are now ignored.

## 1.1.9: 2014-12-13

### Improvements

  * Supported "InvalidValue" error message normalization at the top level.

## 1.1.8: 2014-12-13

### Improvements

  * Supported "InvalidValue" error message normalization.

## 1.1.7: 2014-11-18

 * Accept virtual column like `_key` as a part of Groonga's `column_list` command response.

## 1.1.6: 2014-09-29

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

# News

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

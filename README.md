> **Note:** this repository is an unofficial, patched build of PHP 5.5.38
> maintained for a deployment that cannot upgrade yet. It is not the official
> PHP repository and does not accept upstream contributions. PHP 5.5 is
> end-of-life; upgrading to a supported PHP version remains the recommended
> path.
>
> - Changes and test results: [pull request #1](https://github.com/re-cinq/php-5-5-38-patched/pull/1)
> - Recommended runtime configuration: [`config/php2shell/README.md`](config/php2shell/README.md)
> - CI: [`.github/workflows/php2shell.yml`](.github/workflows/php2shell.yml)
>
> The original PHP 5.5.38 README follows.

The PHP Interpreter
===================

This is the github mirror of the official PHP repository located at
http://git.php.net.

[![Build Status](https://secure.travis-ci.org/php/php-src.png?branch=master)](http://travis-ci.org/php/php-src)

Pull Requests
=============
PHP accepts pull requests via github. Discussions are done on github, but
depending on the topic can also be relayed to the official PHP developer
mailinglist internals@lists.php.net.

New features require an RFC and must be accepted by the developers.
See https://wiki.php.net/rfc and https://wiki.php.net/rfc/voting for more
information on the process.

Bug fixes **do not** require an RFC, but require a bugtracker ticket. Always
open a ticket at https://bugs.php.net and reference the bug id using #NNNNNN.

    Fix #55371: get_magic_quotes_gpc() throws deprecation warning

    After removing magic quotes, the get_magic_quotes_gpc function caused
    a deprecate warning. get_magic_quotes_gpc can be used to detected
    the magic_quotes behavior and therefore should not raise a warning at any
    time. The patch removes this warning

We do not merge pull requests directly on github. All PRs will be
pulled and pushed through http://git.php.net.


Guidelines for contributors
===========================
- [CODING_STANDARDS](/CODING_STANDARDS)
- [README.GIT-RULES](/README.GIT-RULES)
- [README.MAILINGLIST_RULES](/README.MAILINGLIST_RULES)
- [README.RELEASE_PROCESS](/README.RELEASE_PROCESS)


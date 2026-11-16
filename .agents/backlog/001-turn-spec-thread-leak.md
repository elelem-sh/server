As a `contributor running the elelem-server specs`, I `want each
example to finish its turn threads before the next one starts`, so
that `the output shows only real failures and the suite does not
depend on order`.

# SYNOPSIS

Join or kill the turn threads that turn_spec.rb starts.

# DESCRIPTION

`Server#message` starts each turn on a new thread:
`Thread.new { tab.run(text) }` (server.rb:153). In
spec/elelem/server/turn_spec.rb the session double's `turn` blocks on a
`gate` queue (turn_spec.rb:6, :12). Some examples end while a turn is
still waiting on the gate. The thread wakes later, during another
example, and calls the expired `double("session")`. Each run prints
about 19 traces like:

```
#<Thread:... server.rb:153 run> terminated with exception (report_on_exception is true):
... #<Double "session"> was originally created in one example but has leaked into another example and can no longer be used. (RSpec::Mocks::ExpiredTestDoubleError)
  from lib/elelem/server/tab.rb:16 in 'Elelem::Server::Tab#terminal'
```

The specs still pass, but the noise hides real failures, and leaked
threads can change the result of later examples.

Options:

* Keep track of the threads `message` starts (for example a
  `@turns` list on the server, which also helps shutdown), and join or
  kill them in an `after` hook.
* Give the specs a way to wait for a turn to finish, and release every
  waiting turn through the gate before each example ends.

# SEE ALSO

* [ ] lib/elelem/server.rb:146-155 - message starts the turn thread
* [ ] lib/elelem/server/tab.rb:16 - where the leaked thread fails
* [ ] spec/elelem/server/turn_spec.rb:6-12 - gate and session double
* [ ] spec/elelem/server/turn_spec.rb:73 - another Thread.new in specs
* [ ] Formerly elelem-sh/elelem.sh#54

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] `bin/test` prints no "terminated with exception" lines
* [ ] No thread started by an example is alive after that example ends
* [ ] The suite passes with `--order rand` for several seeds

As a `person who wants to use elelem from a browser`, I `want a
README in the elelem-server repository`, so that `I can start the
server safely and know what it exposes`.

# SYNOPSIS

Add a short README.

# DESCRIPTION

The repository has no README. It should cover:

* Install and start: `elelem-server`, with `-p/--provider` (default
  from `ELELEM_PROVIDER`, else `demo`), `--port` (default 4567) and
  `--bind` (default 127.0.0.1).
* Security: the server runs an agent with whatever tools are loaded,
  so binding to anything other than localhost exposes a shell to the
  network. Say what the guard protects and what it does not
  (lib/elelem/server.rb, spec/elelem/server/guard_spec.rb).
* Tabs: one conversation per browser tab, one turn at a time, and the
  limit on open tabs.
* A link to https://elelem.sh/plugins/server/.

Show commands without a leading `$`.

# SEE ALSO

* [ ] exe/elelem-server - options and defaults
* [ ] lib/elelem/server.rb - routes, guard, tabs
* [ ] https://elelem.sh/plugins/server/
* [ ] Formerly elelem-sh/elelem.sh#23

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] README.md exists and covers start options, security and tabs
* [ ] Defaults in the README match exe/elelem-server
* [ ] Commands have no leading `$`

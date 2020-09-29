#!/usr/bin/env zsh

set -euo pipefail

ENTRYPOINT_SCRIPT_LOCATION="${ENTRYPOINT_SCRIPT_LOCATION:-${HOME}/tools/coffeescript/generated-entrypoint-script.js}"

function generate-entrypoint-script {
  cat > "$ENTRYPOINT_SCRIPT_LOCATION" <<EOF
  console.error initArgv: process.argv
  [,,,...process.argv] = process.argv
  process.argv = ['coffee', '???', ...process.argv]
  console.log argv: process.argv
  command.run()
EOF
}

function err {
  echo >&2 "$@"
}

function print-args-and-exit {
  err 'args were:'
  printf >&2 '%s\n' "$@"
  exit 1
}

function validate-repl-command-line {
  set +x
  if [[ "$(echo "$@")" != '-i' ]]; then
    err 'invalid command line: expected just "-i"'
    print-args-and-exit "$@"
  fi
  set -x
}

if printf '%s\n' "$@" | grep -qE '^\-i$'; then
  validate-repl-command-line "$@" \
    && coffee -r ~/tools/coffeescript/lib/coffeescript/repl.js -e 'repl.start()'
else
  generate-entrypoint-script \
    && coffee \
         -r ~/tools/coffeescript/lib/coffeescript/command.js \
         "$@" \
         "$ENTRYPOINT_SCRIPT_LOCATION"
fi

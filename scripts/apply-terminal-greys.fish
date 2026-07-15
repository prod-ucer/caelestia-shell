#!/usr/bin/env fish

set -l scheme_file "$HOME/.local/state/caelestia/scheme.json"
set -l colours "$SCHEME_COLOURS"

if test -z "$colours"
    test -r "$scheme_file"; or exit 0
    set colours (jq -c '.colours' "$scheme_file" 2>/dev/null)
end

set -l outline (printf '%s' "$colours" | jq -r '.outline // empty')
set -l muted (printf '%s' "$colours" | jq -r '.onSurfaceVariant // empty')
set -l foreground (printf '%s' "$colours" | jq -r '.onSurface // empty')

test -n "$outline" -a -n "$muted" -a -n "$foreground"; or exit 0

set -l sequence (printf '\e]4;243;#%s\e\\\e]4;244;#%s\e\\\e]4;245;#%s\e\\' "$outline" "$muted" "$foreground")

if test "$argv[1]" = --all
    for pt in /dev/pts/[0-9]*
        test -w "$pt"; and printf '%s' "$sequence" >"$pt" 2>/dev/null
    end
else
    printf '%s' "$sequence"
end

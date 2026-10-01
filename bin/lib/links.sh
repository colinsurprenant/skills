# Link tests shared by bin/install and bin/doctor, so the two cannot disagree
# about what counts as this clone's link. Sourced, not run; expects $repo to
# hold this clone's physical root.

# A link counts only if it resolves to exactly its documented target. A link
# to some other file, even one inside this clone, is not ours: install leaves
# it alone, and doctor reports it as the drift it is.
links_to() { # links_to <link> <absolute expected target>
  local t
  [ -L "$1" ] || return 1
  t="$(readlink "$1")"
  case "$t" in /*) ;; *) t="$(dirname "$1")/$t" ;; esac
  [ "$(CDPATH='' cd -P -- "$(dirname "$t")" 2>/dev/null && pwd -P)/$(basename "$t")" = "$2" ]
}

# The links a pre-rename install created, as <path under ~/.claude>:<old
# repo-relative target>. bin/install removes them; bin/doctor flags them.
pre_rename_links=(skills/opus-build:opus-build
                  agents/opus-builder.md:agents/opus-builder.md
                  agents/opus-reviewer.md:agents/opus-reviewer.md)

# True if <link> is a symlink naming exactly "$repo/<old target>", the path a
# pre-rename install created. That target is dangling by construction, so only
# its directory is resolved, physically; a link whose directory does not
# resolve, or that names anything else (another clone, a live file in this one,
# a `..` escape), is not ours.
is_pre_rename_link() { # is_pre_rename_link <link> <repo-relative old target>
  local t d
  [ -L "$1" ] || return 1
  t="$(readlink "$1")"
  case "$t" in
    /*) ;;
    *) d="$(CDPATH='' cd -P -- "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
       t="$d/$t" ;;
  esac
  d="$(CDPATH='' cd -P -- "$(dirname "$t")" 2>/dev/null && pwd -P)" || return 1
  [ "$d/$(basename "$t")" = "$repo/$2" ]
}

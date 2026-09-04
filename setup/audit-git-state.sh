#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
    set -- \
        "$HOME/repos" \
        "$HOME/worktrees" \
        "$HOME/.config/agent-overflow/worktrees" \
        "$HOME/.orc/worktrees"
fi

existing_roots=()
for root in "$@"; do
    [[ -d "$root" ]] && existing_roots+=("$root")
done

if [[ "${#existing_roots[@]}" -eq 0 ]]; then
    printf 'No Git roots found.\n' >&2
    exit 1
fi

declare -A seen=()
printf 'path\tbranch\thead\tupstream\tahead\tbehind\tchanged\tuntracked\n'

while IFS= read -r marker; do
    worktree="${marker%/.git}"
    top="$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$top" && -z "${seen[$top]:-}" ]] || continue
    seen["$top"]=1

    branch="$(git -C "$top" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')"
    head="$(git -C "$top" rev-parse HEAD)"
    upstream="$(git -C "$top" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || printf '-')"
    ahead=0
    behind=0
    if [[ "$upstream" != "-" ]]; then
        read -r behind ahead < <(
            git -C "$top" rev-list --left-right --count '@{upstream}...HEAD'
        )
    fi

    status="$(git -C "$top" status --porcelain=v1 --untracked-files=all)"
    changed=0
    untracked=0
    if [[ -n "$status" ]]; then
        changed="$(printf '%s\n' "$status" | grep -c -v '^??' || true)"
        untracked="$(printf '%s\n' "$status" | grep -c '^??' || true)"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$top" "$branch" "$head" "$upstream" "$ahead" "$behind" "$changed" "$untracked"
done < <(
    find "${existing_roots[@]}" \
        \( -type d -name .git -prune -o -type f -name .git \) -print 2>/dev/null \
        | LC_ALL=C sort -u
)

#!/usr/bin/env bash
# User-local tools the distro repositories lack (RHEL-family in particular),
# installed from each project's own release into ~/.local/bin. Linux only:
# every archive below is a Linux build, and on macOS the Brewfile carries
# the same tools.
#
# Usage: user-tools.sh [--upgrade] [CATEGORY...]
#   No categories: every category. Without --upgrade a tool already on PATH
#   is skipped, so versions another setup installed stay put; with --upgrade
#   the named categories are reinstalled from their latest release.
set -euo pipefail

declare -A CATEGORIES=(
    [shell]="zoxide lazygit delta eza direnv bun"
    [k8s]="kubectl helm k9s argocd minikube linkerd"
    [secrets]="sops age"
    [dev]="glab shellcheck yq mongosh"
    [docs]="typst pandoc"
)
CATEGORY_ORDER=(shell k8s secrets dev docs)

UPGRADE=0

usage() {
    echo "Usage: $(basename "$0") [--upgrade] [CATEGORY...]"
    echo "Categories:"
    local category
    for category in "${CATEGORY_ORDER[@]}"; do
        printf '  %-8s %s\n' "$category" "${CATEGORIES[$category]}"
    done
}

# Release-asset arch names: Go-style (amd64/arm64) and uname-style (x86_64/aarch64).
go_arch() {
    case "$(uname -m)" in
        x86_64) echo amd64 ;;
        aarch64|arm64) echo arm64 ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

uname_arch() {
    case "$(uname -m)" in
        x86_64) echo x86_64 ;;
        aarch64|arm64) echo aarch64 ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

github_latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -er '.tag_name'
}

# install_release_binary NAME URL [MEMBER...]
# Installs URL as ~/.local/bin/NAME. With MEMBERs, URL is a tar archive and
# each MEMBER (a path inside it) is installed under its own basename.
install_release_binary() {
    local name="$1" url="$2"
    shift 2
    echo "Installing $name from $url"
    (
        local tmpdir member
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        curl -fsSL "$url" -o "$tmpdir/download"
        if [[ $# -eq 0 ]]; then
            install -Dm755 "$tmpdir/download" "$HOME/.local/bin/$name"
            return 0
        fi
        tar -xf "$tmpdir/download" -C "$tmpdir"
        for member in "$@"; do
            install -Dm755 "$tmpdir/$member" "$HOME/.local/bin/$(basename "$member")"
        done
    )
}

# True when NAME should be left alone: it is on PATH and this is not an upgrade.
have() {
    [[ "$UPGRADE" -eq 1 ]] && return 1
    if command -v "$1" &>/dev/null; then
        echo "$1 already installed"
        return 0
    fi
    return 1
}

# ─── shell ────────────────────────────────────────────────────────────────────

install_zoxide() {
    have zoxide && return 0
    local tag target
    tag="$(github_latest_tag ajeetdsouza/zoxide)"
    target="$(uname_arch)-unknown-linux-musl"
    install_release_binary zoxide \
        "https://github.com/ajeetdsouza/zoxide/releases/download/$tag/zoxide-${tag#v}-$target.tar.gz" zoxide
}

install_lazygit() {
    have lazygit && return 0
    local tag arch
    tag="$(github_latest_tag jesseduffield/lazygit)"
    arch="$(uname_arch)"
    [[ "$arch" == "aarch64" ]] && arch="arm64"
    install_release_binary lazygit \
        "https://github.com/jesseduffield/lazygit/releases/download/$tag/lazygit_${tag#v}_linux_$arch.tar.gz" lazygit
}

install_delta() {
    have delta && return 0
    local tag target
    tag="$(github_latest_tag dandavison/delta)"
    target="$(uname_arch)-unknown-linux-gnu"
    install_release_binary delta \
        "https://github.com/dandavison/delta/releases/download/$tag/delta-$tag-$target.tar.gz" "delta-$tag-$target/delta"
}

install_eza() {
    have eza && return 0
    local tag
    tag="$(github_latest_tag eza-community/eza)"
    install_release_binary eza \
        "https://github.com/eza-community/eza/releases/download/$tag/eza_$(uname_arch)-unknown-linux-gnu.tar.gz" ./eza
}

install_direnv() {
    have direnv && return 0
    local tag
    tag="$(github_latest_tag direnv/direnv)"
    install_release_binary direnv \
        "https://github.com/direnv/direnv/releases/download/$tag/direnv.linux-$(go_arch)"
}

# Bun lives in ~/.bun (toolchains.sh puts it on PATH) and ships as a zip.
install_bun() {
    if [[ "$UPGRADE" -eq 0 && -x "$HOME/.bun/bin/bun" ]]; then
        echo "bun already installed"
        return 0
    fi
    local tag asset
    tag="$(github_latest_tag oven-sh/bun)"
    asset="bun-linux-$(uname_arch)"
    [[ "$asset" == "bun-linux-x86_64" ]] && asset="bun-linux-x64"
    echo "Installing bun ${tag#bun-v}"
    (
        local tmpdir
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        curl -fsSL "https://github.com/oven-sh/bun/releases/download/$tag/$asset.zip" -o "$tmpdir/bun.zip"
        unzip -q "$tmpdir/bun.zip" -d "$tmpdir"
        install -Dm755 "$tmpdir/$asset/bun" "$HOME/.bun/bin/bun"
        ln -sfn bun "$HOME/.bun/bin/bunx"
    )
}

# ─── k8s ──────────────────────────────────────────────────────────────────────

install_kubectl() {
    have kubectl && return 0
    local version
    version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    install_release_binary kubectl "https://dl.k8s.io/release/$version/bin/linux/$(go_arch)/kubectl"
}

install_helm() {
    have helm && return 0
    local tag arch
    tag="$(github_latest_tag helm/helm)"
    arch="$(go_arch)"
    install_release_binary helm "https://get.helm.sh/helm-$tag-linux-$arch.tar.gz" "linux-$arch/helm"
}

install_k9s() {
    have k9s && return 0
    local tag
    tag="$(github_latest_tag derailed/k9s)"
    install_release_binary k9s \
        "https://github.com/derailed/k9s/releases/download/$tag/k9s_Linux_$(go_arch).tar.gz" k9s
}

install_argocd() {
    have argocd && return 0
    local tag
    tag="$(github_latest_tag argoproj/argo-cd)"
    install_release_binary argocd \
        "https://github.com/argoproj/argo-cd/releases/download/$tag/argocd-linux-$(go_arch)"
}

install_minikube() {
    have minikube && return 0
    local tag
    tag="$(github_latest_tag kubernetes/minikube)"
    install_release_binary minikube \
        "https://github.com/kubernetes/minikube/releases/download/$tag/minikube-linux-$(go_arch)"
}

# Linkerd publishes only edge releases on GitHub; stable builds come from Buoyant.
install_linkerd() {
    have linkerd && return 0
    local tag
    tag="$(github_latest_tag linkerd/linkerd2)"
    install_release_binary linkerd \
        "https://github.com/linkerd/linkerd2/releases/download/$tag/linkerd2-cli-$tag-linux-$(go_arch)"
}

# ─── secrets ──────────────────────────────────────────────────────────────────

install_sops() {
    have sops && return 0
    local tag
    tag="$(github_latest_tag getsops/sops)"
    install_release_binary sops \
        "https://github.com/getsops/sops/releases/download/$tag/sops-$tag.linux.$(go_arch)"
}

install_age() {
    have age && return 0
    local tag
    tag="$(github_latest_tag FiloSottile/age)"
    install_release_binary age \
        "https://github.com/FiloSottile/age/releases/download/$tag/age-$tag-linux-$(go_arch).tar.gz" \
        age/age age/age-keygen
}

# ─── dev ──────────────────────────────────────────────────────────────────────

install_glab() {
    have glab && return 0
    local version
    version="$(
        curl -fsSL 'https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest' \
            | jq -er '.tag_name | ltrimstr("v")'
    )"
    install_release_binary glab \
        "https://gitlab.com/gitlab-org/cli/-/releases/v$version/downloads/glab_${version}_linux_$(go_arch).tar.gz" \
        bin/glab
}

install_shellcheck() {
    have shellcheck && return 0
    local tag
    tag="$(github_latest_tag koalaman/shellcheck)"
    install_release_binary shellcheck \
        "https://github.com/koalaman/shellcheck/releases/download/$tag/shellcheck-$tag.linux.$(uname_arch).tar.xz" \
        "shellcheck-$tag/shellcheck"
}

install_yq() {
    have yq && return 0
    local tag
    tag="$(github_latest_tag mikefarah/yq)"
    install_release_binary yq \
        "https://github.com/mikefarah/yq/releases/download/$tag/yq_linux_$(go_arch)"
}

install_mongosh() {
    have mongosh && return 0
    local version arch
    version="$(github_latest_tag mongodb-js/mongosh)"
    version="${version#v}"
    arch="$(go_arch)"
    [[ "$arch" == "amd64" ]] && arch="x64"
    install_release_binary mongosh \
        "https://downloads.mongodb.com/compass/mongosh-$version-linux-$arch.tgz" \
        "mongosh-$version-linux-$arch/bin/mongosh"
}

# ─── docs ─────────────────────────────────────────────────────────────────────

install_typst() {
    have typst && return 0
    local tag target
    tag="$(github_latest_tag typst/typst)"
    target="$(uname_arch)-unknown-linux-musl"
    install_release_binary typst \
        "https://github.com/typst/typst/releases/download/$tag/typst-$target.tar.xz" "typst-$target/typst"
}

install_pandoc() {
    have pandoc && return 0
    local tag
    tag="$(github_latest_tag jgm/pandoc)"
    install_release_binary pandoc \
        "https://github.com/jgm/pandoc/releases/download/$tag/pandoc-$tag-linux-$(go_arch).tar.gz" \
        "pandoc-$tag/bin/pandoc"
}

# ─── main ─────────────────────────────────────────────────────────────────────

main() {
    local selected=() category tool
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --upgrade) UPGRADE=1 ;;
            -h|--help) usage; return 0 ;;
            *)
                if [[ -z "${CATEGORIES[$1]:-}" ]]; then
                    echo "Unknown category: $1" >&2
                    usage >&2
                    return 1
                fi
                selected+=("$1")
                ;;
        esac
        shift
    done
    [[ ${#selected[@]} -eq 0 ]] && selected=("${CATEGORY_ORDER[@]}")

    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "User tools are Linux-only here; on macOS run: brew bundle --file=Brewfile"
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"

    for category in "${selected[@]}"; do
        for tool in ${CATEGORIES[$category]}; do
            "install_$tool"
        done
    done
    local verb="set up"
    [[ "$UPGRADE" -eq 1 ]] && verb="upgraded"
    echo "User tools $verb: ${selected[*]}"
}

main "$@"

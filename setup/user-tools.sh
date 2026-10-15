#!/usr/bin/env bash
# User-local tools the distro repositories lack (RHEL-family in particular),
# installed from each project's own release into ~/.local/bin. Linux only:
# every archive below is a Linux build, and on macOS the Brewfile carries
# the same tools.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "User tools are Linux-only here; on macOS run: brew bundle --file=Brewfile"
    exit 0
fi

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

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

# Skips a tool already on PATH, so machine-pinned versions (e.g. installed
# by a work setup) are left alone.
have() {
    if command -v "$1" &>/dev/null; then
        echo "$1 already installed"
        return 0
    fi
    return 1
}

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

install_yq() {
    have yq && return 0
    local tag
    tag="$(github_latest_tag mikefarah/yq)"
    install_release_binary yq \
        "https://github.com/mikefarah/yq/releases/download/$tag/yq_linux_$(go_arch)"
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

install_shellcheck() {
    have shellcheck && return 0
    local tag
    tag="$(github_latest_tag koalaman/shellcheck)"
    install_release_binary shellcheck \
        "https://github.com/koalaman/shellcheck/releases/download/$tag/shellcheck-$tag.linux.$(uname_arch).tar.xz" \
        "shellcheck-$tag/shellcheck"
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

install_zoxide() {
    if command -v zoxide &>/dev/null; then
        echo "zoxide already installed ($(zoxide --version))"
        return 0
    fi

    echo "Installing zoxide from its official release installer..."
    local installer
    installer="$(mktemp)"
    trap 'rm -f "$installer"' RETURN
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
        -o "$installer"
    sh "$installer"
    trap - RETURN
    rm -f "$installer"
}

install_lazygit() {
    if command -v lazygit &>/dev/null; then
        echo "lazygit already installed ($(lazygit --version | head -1))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            echo "Unsupported architecture for lazygit: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing lazygit $version from its official release..."
    (
        local tmpdir archive
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/lazygit.tar.gz"
        curl -fsSL \
            "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch}.tar.gz" \
            -o "$archive"
        tar -xzf "$archive" -C "$tmpdir" lazygit
        install -Dm755 "$tmpdir/lazygit" "$HOME/.local/bin/lazygit"
    )
}

install_delta() {
    if command -v delta &>/dev/null; then
        echo "delta already installed ($(delta --version))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) arch="aarch64-unknown-linux-gnu" ;;
        *)
            echo "Unsupported architecture for delta: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing delta $version from its official release..."
    (
        local tmpdir archive delta_bin
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/delta.tar.gz"
        curl -fsSL \
            "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-${arch}.tar.gz" \
            -o "$archive"
        tar -xzf "$archive" -C "$tmpdir"
        delta_bin="$(find "$tmpdir" -type f -name delta -perm -u+x -print -quit)"
        if [[ -z "$delta_bin" ]]; then
            echo "The delta release archive did not contain an executable" >&2
            return 1
        fi
        install -Dm755 "$delta_bin" "$HOME/.local/bin/delta"
    )
}

install_eza() {
    if command -v eza &>/dev/null; then
        echo "eza already installed ($(eza --version | head -1))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) arch="aarch64-unknown-linux-gnu" ;;
        *)
            echo "Unsupported architecture for eza: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing eza $version from its official release..."
    (
        local tmpdir archive
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/eza.tar.gz"
        curl -fsSL \
            "https://github.com/eza-community/eza/releases/download/v${version}/eza_${arch}.tar.gz" \
            -o "$archive"
        tar -xzf "$archive" -C "$tmpdir"
        install -Dm755 "$tmpdir/eza" "$HOME/.local/bin/eza"
    )
}

install_direnv() {
    if command -v direnv &>/dev/null; then
        echo "direnv already installed ($(direnv version))"
        return 0
    fi

    local arch version
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            echo "Unsupported architecture for direnv: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/direnv/direnv/releases/latest \
            | jq -er '.tag_name | ltrimstr("v")'
    )"

    echo "Installing direnv $version from its official release..."
    curl -fsSL \
        "https://github.com/direnv/direnv/releases/download/v${version}/direnv.linux-${arch}" \
        -o "$HOME/.local/bin/direnv"
    chmod 0755 "$HOME/.local/bin/direnv"
}

install_bun() {
    if [[ -x "$HOME/.bun/bin/bun" ]]; then
        echo "Bun already installed ($("$HOME/.bun/bin/bun" --version))"
        return 0
    fi

    local asset version
    case "$(uname -m)" in
        x86_64) asset="bun-linux-x64" ;;
        aarch64|arm64) asset="bun-linux-aarch64" ;;
        *)
            echo "Unsupported architecture for Bun: $(uname -m)" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL https://api.github.com/repos/oven-sh/bun/releases/latest \
            | jq -er '.tag_name'
    )"

    echo "Installing Bun ${version#bun-v} from its official release..."
    (
        local tmpdir archive
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        archive="$tmpdir/bun.zip"
        curl -fsSL \
            "https://github.com/oven-sh/bun/releases/download/${version}/${asset}.zip" \
            -o "$archive"
        unzip -q "$archive" -d "$tmpdir"
        install -Dm755 "$tmpdir/$asset/bun" "$HOME/.bun/bin/bun"
        ln -s bun "$HOME/.bun/bin/bunx"
    )
}

install_zoxide
install_lazygit
install_delta
install_eza
install_direnv
install_bun
install_kubectl
install_helm
install_k9s
install_argocd
install_sops
install_age
install_yq
install_minikube
install_linkerd
install_glab
install_typst
install_pandoc
install_shellcheck
install_mongosh

echo "User tools setup complete."

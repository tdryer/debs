output_dir := "/srv/local-apt-repository"
pkg_dir := "packages"

# Show recipes
default:
    just --list

# Build all Debian packages
build: build-uv build-mdserve build-just build-neovim build-kitty build-codex build-copilot build-diff2html build-fzf build-typos build-ghostty

# Generic build recipe
_build pkg version:
    #!/usr/bin/env bash
    set -eu
    if [ -f {{output_dir}}/{{pkg}}_{{version}}-1_amd64.deb ]; then
        echo "{{pkg}} {{version}} already built, skipping."
        exit 0
    fi
    printf '{{pkg}} ({{version}}-1) unstable; urgency=medium\n\n  * Package {{pkg}} {{version}} from upstream release binaries.\n\n -- Local Builder <builder@localhost>  %s\n' \
        "$(date -R)" > {{pkg_dir}}/{{pkg}}/debian/changelog
    (cd {{pkg_dir}}/{{pkg}} && PKG_VERSION={{version}} dpkg-buildpackage -us -uc -b)
    mkdir -p "{{output_dir}}"
    mv "{{pkg_dir}}/{{pkg}}_{{version}}-1_amd64.deb" "{{output_dir}}/"

# Build uv Debian package
build-uv: (_build "uv" `common/get-latest-version astral-sh/uv`)

# Build mdserve Debian package
build-mdserve: (_build "mdserve" `common/get-latest-version jfernandez/mdserve --strip-prefix v`)

# Build just Debian package
build-just: (_build "just" `common/get-latest-version casey/just`)

# Build neovim Debian package
build-neovim: (_build "neovim" `common/get-latest-version neovim/neovim --strip-prefix v`)

# Build kitty Debian package
build-kitty: (_build "kitty" `common/get-latest-version kovidgoyal/kitty --strip-prefix v`)

# Build codex Debian package
build-codex: (_build "codex" `common/get-latest-version openai/codex --strip-prefix rust-v`)

# Build copilot Debian package
build-copilot: (_build "copilot" `common/get-latest-version github/copilot-cli --strip-prefix v`)

# Build diff2html Debian package
build-diff2html: (_build "diff2html" `common/get-latest-version tdryer/diff2html-rs`)

# Build fzf Debian package
build-fzf: (_build "fzf" `common/get-latest-version junegunn/fzf --strip-prefix v`)

# Build typos Debian package
build-typos: (_build "typos" `common/get-latest-version crate-ci/typos --strip-prefix v`)

# Build ghostty Debian package
build-ghostty: (_build "ghostty" `common/get-latest-version mkasberg/ghostty-ubuntu | sed 's/-0-ppa[0-9]*//'`)

# Remove build artifacts
clean:
    rm -f {{pkg_dir}}/*.deb {{pkg_dir}}/*.buildinfo {{pkg_dir}}/*.changes
    for pkg in {{pkg_dir}}/*/debian/rules; do \
        pkg=$(basename ${pkg%%/debian/rules}); \
        rm -rf {{pkg_dir}}/$pkg/debian/.debhelper/ {{pkg_dir}}/$pkg/debian/debhelper-build-stamp \
               {{pkg_dir}}/$pkg/debian/files {{pkg_dir}}/$pkg/debian/*.substvars \
               {{pkg_dir}}/$pkg/debian/$pkg/ {{pkg_dir}}/$pkg/debian/changelog \
               {{pkg_dir}}/$pkg/debian/*.debhelper {{pkg_dir}}/$pkg/*.deb; \
    done
    rm -rf {{pkg_dir}}/*/source/ {{pkg_dir}}/*/*.tar.gz

# Run setup playbook
playbook:
    ansible-playbook --ask-become-pass playbook.yaml

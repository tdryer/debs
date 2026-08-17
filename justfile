output_dir := "/srv/local-apt-repository"
pkg_dir := "packages"
force := "false"
retain := "3"

# Show recipes
default:
    just --list

# Build all Debian packages
build: \
    build-codex \
    build-copilot \
    build-diff2html \
    build-fence \
    build-fzf \
    build-gh \
    build-ghostty \
    build-just \
    build-kitty \
    build-mdserve \
    build-neovim \
    build-opencode \
    build-typos \
    build-uv \
    build-zed \
    build-nono-cli

# Build and install one or more Debian packages
install +packages:
    #!/usr/bin/env bash
    set -euo pipefail
    packages=( {{packages}} )
    for package in "${packages[@]}"; do
        if ! just --summary | tr ' ' '\n' | grep -Fxq "build-$package"; then
            printf 'Unknown package: %s\n' "$package" >&2
            exit 1
        fi
    done
    for package in "${packages[@]}"; do
        just "build-$package"
    done
    sudo systemctl start --wait local-apt-repository.service
    sudo apt update
    sudo apt install "${packages[@]}"

# Generic build recipe
_build pkg version:
    #!/usr/bin/env bash
    set -eu
    if [ "{{force}}" != "true" ] && [ -f {{output_dir}}/{{pkg}}_{{version}}-1_amd64.deb ]; then
        echo "{{pkg}} {{version}} already built, skipping."
        exit 0
    fi
    printf '{{pkg}} ({{version}}-1) unstable; urgency=medium\n\n  * Package {{pkg}} {{version}} from upstream release binaries.\n\n -- Local Builder <builder@localhost>  %s\n' \
        "$(date -R)" > {{pkg_dir}}/{{pkg}}/debian/changelog
    (cd {{pkg_dir}}/{{pkg}} && PKG_VERSION={{version}} dpkg-buildpackage -us -uc -b --post-clean)
    mkdir -p "{{output_dir}}"
    mv "{{pkg_dir}}/{{pkg}}_{{version}}-1_amd64.deb" "{{output_dir}}/"

# Generic recipe to download a pre-built upstream deb as-is
_download_deb pkg version url_template:
    #!/usr/bin/env bash
    set -eu
    url="{{url_template}}"
    url=$(sed "s/{{"{{"}}version{{"}}"}}/{{version}}/g" <<< "$url")
    deb="${url##*/}"
    if [ "{{force}}" != "true" ] && [ -f {{output_dir}}/"$deb" ]; then
        echo "{{pkg}} {{version}} already built, skipping."
        exit 0
    fi
    curl --fail --show-error -sL -o "$deb" "$url"
    mkdir -p "{{output_dir}}"
    mv "$deb" "{{output_dir}}/"

# Build uv Debian package
build-uv: (_build "uv" `gh release list --repo astral-sh/uv --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName'`)

# Build mdserve Debian package
build-mdserve: (_build "mdserve" `gh release list --repo jfernandez/mdserve --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build just Debian package
build-just: (_build "just" `gh release list --repo casey/just --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName'`)

# Build neovim Debian package
build-neovim: (_build "neovim" `gh release list --repo neovim/neovim --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build kitty Debian package
build-kitty: (_build "kitty" `gh release list --repo kovidgoyal/kitty --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build codex Debian package
build-codex: (_build "codex" `gh release list --repo openai/codex --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("rust-v")'`)

# Build copilot Debian package
build-copilot: (_build "copilot" `gh release list --repo github/copilot-cli --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build diff2html Debian package
build-diff2html: (_build "diff2html" `gh release list --repo tdryer/diff2html-rs --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName'`)

# Build fzf Debian package
build-fzf: (_build "fzf" `gh release list --repo junegunn/fzf --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build typos Debian package
build-typos: (_build "typos" `gh release list --repo crate-ci/typos --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build gh Debian package
build-gh: (_download_deb "gh" `gh release list --repo cli/cli --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'` "https://github.com/cli/cli/releases/download/v{{version}}/gh_{{version}}_linux_amd64.deb")

# Build ghostty Debian package
build-ghostty: (_build "ghostty" `gh release list --repo mkasberg/ghostty-ubuntu --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | gsub("-0-ppa[0-9]*$"; "")'`)

# Build fence Debian package
build-fence: (_build "fence" `gh release list --repo fencesandbox/fence --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build opencode Debian package
build-opencode: (_build "opencode" `gh release list --repo anomalyco/opencode --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build zed Debian package
build-zed: (_build "zed" `gh release list --repo zed-industries/zed --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'`)

# Build nono-cli Debian package
build-nono-cli: (_download_deb "nono-cli" `gh release list --repo nolabs-ai/nono --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName | ltrimstr("v")'` "https://github.com/nolabs-ai/nono/releases/download/v{{version}}/nono-cli_{{version}}_amd64.deb")

# Retain only the configured number of newest versions of each package
prune-repository:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob

    declare -A package_files package_versions
    for deb in "{{output_dir}}"/*.deb; do
        package=$(dpkg-deb --field "$deb" Package)
        version=$(dpkg-deb --field "$deb" Version)
        package_files["$package"]+=$'\n'"$deb"
        package_versions["$package"]+=$'\n'"$version"
    done

    for package in "${!package_files[@]}"; do
        mapfile -t files < <(printf '%s\n' "${package_files[$package]}" | sed '/^$/d')
        mapfile -t versions < <(printf '%s\n' "${package_versions[$package]}" | sed '/^$/d')
        order=()
        for index in "${!files[@]}"; do
            insert_at=${#order[@]}
            for position in "${!order[@]}"; do
                if dpkg --compare-versions "${versions[$index]}" gt "${versions[${order[$position]}]}"; then
                    insert_at=$position
                    break
                fi
            done
            order=("${order[@]:0:insert_at}" "$index" "${order[@]:insert_at}")
        done

        for position in "${order[@]:{{retain}}}"; do
            printf 'Removing old %s package: %s\n' "$package" "${files[$position]}"
            rm -- "${files[$position]}"
        done
    done

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

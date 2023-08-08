#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/aabouzaid/asdf-plugin-manager"
TOOL_NAME="asdf-plugin-manager"
TOOL_TEST="asdf-plugin-manager list"

fail() {
    echo -e "asdf-$TOOL_NAME: $*"
    exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
    curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
    sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
        LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
    git ls-remote --tags --refs "$GH_REPO" |
        grep -o 'refs/tags/.*' | cut -d/ -f3- | sed 's/^v//'
}

list_all_versions() {
    list_github_tags
}

download_release() {
    local version filename url
    version="$1"
    filename="$2"
    url="$GH_REPO/releases/download/v${version}/asdf-plugin-manager-v${version}.sh"

    echo "* Downloading $TOOL_NAME release $version..."
    curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
    local install_type="$1"
    local version="$2"
    local install_path="${3%/bin}/bin"

    if [ "$install_type" != "version" ]; then
        fail "asdf-$TOOL_NAME supports release installs only"
    fi

    (
        mkdir -p "$install_path"
        chmod +x "$ASDF_DOWNLOAD_PATH/$TOOL_NAME-$ASDF_INSTALL_VERSION"
        cp "$ASDF_DOWNLOAD_PATH/$TOOL_NAME-$ASDF_INSTALL_VERSION" "$install_path/$TOOL_NAME"

        local tool_cmd
        tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
        test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

        echo "$TOOL_NAME $version installation was successful!"
    ) || (
        rm -rf "$install_path"
        fail "An error occurred while installing $TOOL_NAME $version."
    )
		post_install "${install_path}"
}

post_install() {
	lcoal -r command_shortcut_name="${ASDF_PLUGIN_MANAGER_SHORTCUT_NAME:-"pm"}"
  local -r lib_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
	local -r this_plugin_dir="$(dirname "${lib_dir}")"
	local -r plugins_dir="$(dirname "${this_plugin_dir}")"
  local -r pm_command_dir="${plugins_dir}/${command_shortcut_name}/lib/commands"
  local -r pm_bin_dir="${plugins_dir}/${command_shortcut_name}/bin"
	local -r command_shim="${pm_command_dir}/command-.bash"
	if [ ! -f "${command_shim}" ]; then
    mkdir -p "${pm_command_dir}"
		# this is needed in order for asdf to print `No version is set for command asdf-plugin-manager' on pm command
    mkdir -p "${pm_bin_dir}/bin"
    ln -nfs "${ASDF_DIR}/shims/asdf-plugin-manager" "${command_shim}"
	fi
}

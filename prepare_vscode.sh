#!/usr/bin/env bash
# shellcheck disable=SC1091,2154

set -e

cp -rp src/stable/* vscode/

cp -f LICENSE vscode/LICENSE.txt

cd vscode || { echo "'vscode' dir not found"; exit 1; }

{ set +x; } 2>/dev/null

# {{{ product.json
cp product.json{,.bak}

setpath() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath_json() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --argjson 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

jsonTmp=$( jq -s '.[0] * .[1]' product.json ../product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

if [[ "${DISABLE_UPDATE}" == "yes" ]]; then
  jsonTmp=$( jq 'del(.updateUrl) | del(.downloadUrl)' product.json )
  echo "${jsonTmp}" > product.json && unset jsonTmp
fi

cat product.json
# }}}

# include common functions
. ../utils.sh

# {{{ apply patches

echo "APP_NAME=\"${APP_NAME}\""
echo "APP_NAME_LC=\"${APP_NAME_LC}\""
echo "ASSETS_REPOSITORY=\"${ASSETS_REPOSITORY}\""
echo "BINARY_NAME=\"${BINARY_NAME}\""
echo "GH_REPO_PATH=\"${GH_REPO_PATH}\""
echo "GLOBAL_DIRNAME=\"${GLOBAL_DIRNAME}\""
echo "ORG_NAME=\"${ORG_NAME}\""
echo "TUNNEL_APP_NAME=\"${TUNNEL_APP_NAME}\""

if [[ "${DISABLE_UPDATE}" == "yes" ]]; then
  apply_patch ../patches/00-update-disable.patch.yet
fi

for file in ../patches/*.json; do
  if [[ -f "${file}" ]]; then
    apply_actions "${file}"
  fi
done

for file in ../patches/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

if [[ -d "../patches/${OS_NAME}/" ]]; then
  for file in "../patches/${OS_NAME}/"*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

for file in ../patches/user/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done
# }}}

# {{{ Onyx built-in extensions
for dir in ../extensions/onyx-*/; do
  if [[ -d "${dir}" ]]; then
    echo "bundling built-in extension: $( basename "${dir}" )"
    cp -R "${dir}" "extensions/$( basename "${dir}" )"
  fi
done
# }}}

set -x

# {{{ install dependencies
if [[ "${SKIP_INSTALL}" != "yes" ]]; then
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

if [[ "${OS_NAME}" == "linux" ]]; then
  export VSCODE_SKIP_NODE_VERSION_CHECK=1

  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
else
  if [[ "${CI_BUILD}" != "no" ]]; then
    clang++ --version
  fi
fi

node build/npm/preinstall.ts

for i in {1..5}; do # try 5 times
  if [[ "${CI_BUILD}" != "no" && "${OS_NAME}" == "osx" ]]; then
    CXX=clang++ npm ci && break
  else
    npm ci && break
  fi

  if [[ $i == 5 ]]; then
    echo "Npm install failed too many times" >&2
    exit 1
  fi
  echo "Npm install failed $i, trying again..."

  sleep $(( 15 * (i + 1)))
done
fi
# }}}

# package.json
cp package.json{,.bak}

setpath "package" "version" "${RELEASE_VERSION}"

replace 's|Microsoft Corporation|Onyx|' package.json
replace "s|--max-old-space-size=8192|--max-old-space-size=${MAX_OLD_SPACE_SIZE}|" package.json

cp resources/server/manifest.json{,.bak}

setpath "resources/server/manifest" "name" "Onyx"
setpath "resources/server/manifest" "short_name" "Onyx"

../undo_telemetry.sh

replace 's|Microsoft Corporation|Onyx|' build/lib/electron.ts
replace 's|([0-9]) Microsoft|\1 Onyx|' build/lib/electron.ts

if [[ "${OS_NAME}" == "linux" ]]; then
  # microsoft adds their apt repo to sources
  # unless the app name is code-oss
  # as we are renaming the application to onyx
  # we need to edit a line in the post install template
  sed -i "s/code-oss/onyx/" resources/linux/debian/postinst.template

  # fix the packages metadata
  # code.appdata.xml
  sed -i 's|Visual Studio Code|Onyx|g' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/vundyalaavinash/onyx#install|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://github.com/vundyalaavinash/onyx|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com|https://github.com/vundyalaavinash/onyx|' resources/linux/code.appdata.xml

  # control.template
  sed -i 's|Microsoft Corporation <vscode-linux@microsoft.com>|Onyx contributors https://github.com/vundyalaavinash/onyx/graphs/contributors|'  resources/linux/debian/control.template
  sed -i 's|Visual Studio Code|Onyx|g' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/vundyalaavinash/onyx#install|' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com|https://github.com/vundyalaavinash/onyx|' resources/linux/debian/control.template

  # code.spec.template
  sed -i 's|Microsoft Corporation|Onyx contributors|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code Team <vscode-linux@microsoft.com>|Onyx contributors https://github.com/vundyalaavinash/onyx/graphs/contributors|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|Onyx|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/vundyalaavinash/onyx#install|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com|https://github.com/vundyalaavinash/onyx|' resources/linux/rpm/code.spec.template

  # snapcraft.yaml
  sed -i 's|Visual Studio Code|Onyx|' resources/linux/rpm/code.spec.template
elif [[ "${OS_NAME}" == "windows" ]]; then
  # code.iss
  sed -i 's|https://code.visualstudio.com|https://github.com/vundyalaavinash/onyx|' build/win32/code.iss
  sed -i 's|Microsoft Corporation|Onyx|' build/win32/code.iss
fi

cd ..

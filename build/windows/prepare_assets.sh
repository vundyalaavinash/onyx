#!/usr/bin/env bash

cd vscode || { echo "'vscode' dir not found"; exit 1; }

npm run gulp "vscode-win32-${VSCODE_ARCH}-inno-updater"

# . ../build/windows/appx/build.sh

if [[ "${SHOULD_BUILD_ZIP}" != "no" ]]; then
  7z.exe a -tzip "../assets/${APP_NAME}-win32-${VSCODE_ARCH}-${RELEASE_VERSION}.zip" -x!CodeSignSummary*.md -x!tools "../VSCode-win32-${VSCODE_ARCH}/*" -r
fi

if [[ "${SHOULD_BUILD_EXE_SYS}" != "no" ]]; then
  npm run gulp "vscode-win32-${VSCODE_ARCH}-system-setup"
fi

if [[ "${SHOULD_BUILD_EXE_USR}" != "no" ]]; then
  npm run gulp "vscode-win32-${VSCODE_ARCH}-user-setup"
fi

cd ..

if [[ "${SHOULD_BUILD_EXE_SYS}" != "no" ]]; then
  echo "Moving System EXE"
  mv "vscode\\.build\\win32-${VSCODE_ARCH}\\system-setup\\VSCodeSetup.exe" "assets\\${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
fi

if [[ "${SHOULD_BUILD_EXE_USR}" != "no" ]]; then
  echo "Moving User EXE"
  mv "vscode\\.build\\win32-${VSCODE_ARCH}\\user-setup\\VSCodeSetup.exe" "assets\\${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
fi


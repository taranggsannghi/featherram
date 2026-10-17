#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
version_file="$project_dir/VERSION"
changelog_file="$project_dir/CHANGELOG.md"
version="$(<"$version_file")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  print -u2 "Invalid VERSION: expected MAJOR.MINOR.PATCH."
  exit 1
fi
if ! grep -Fq "## [$version] - " "$changelog_file"; then
  print -u2 "CHANGELOG.md needs an entry for version $version."
  exit 1
fi

build_dir="$(mktemp -d /private/tmp/featherram-release.XXXXXX)"
app_path="$build_dir/FeatherRAM.app"
dist_dir="$project_dir/dist"
versioned_zip="$dist_dir/FeatherRAM-$version.zip"
trap 'rm -rf "$build_dir"' EXIT

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$dist_dir"

cp "$project_dir/FeatherRAM.app/Contents/Info.plist" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString FeatherRAM $version, created by Tarang Sanghi." "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app_path/Contents/Info.plist"
cp "$project_dir/FeatherRAM.app/Contents/PkgInfo" "$app_path/Contents/PkgInfo"
cp "$project_dir/FeatherRAM.app/Contents/Resources/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
cp -R "$project_dir/FeatherRAM.app/Contents/Resources/AppIcon.iconset" "$app_path/Contents/Resources/AppIcon.iconset"
cp "$project_dir/featherram.command" "$app_path/Contents/Resources/featherram.command"
cp "$project_dir/run-featherram.sh" "$app_path/Contents/Resources/run-featherram.sh"
cp "$version_file" "$app_path/Contents/Resources/VERSION"
cp "$changelog_file" "$app_path/Contents/Resources/CHANGELOG.md"
clang "$project_dir/packaging/featherram-launcher.c" -o "$app_path/Contents/MacOS/featherram-launcher"

chmod +x "$app_path/Contents/MacOS/featherram-launcher"
chmod +x "$app_path/Contents/Resources/featherram.command"
chmod +x "$app_path/Contents/Resources/run-featherram.sh"
if [[ "$("$app_path/Contents/Resources/featherram.command" --version)" != "FeatherRAM v$version" ]]; then
  print -u2 "Bundled command version does not match VERSION."
  exit 1
fi
xattr -cr "$app_path"

codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

ditto -c -k --keepParent "$app_path" "$versioned_zip"
cp "$versioned_zip" "$dist_dir/FeatherRAM.zip"

echo "Built $versioned_zip"

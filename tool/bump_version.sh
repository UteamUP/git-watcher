#!/bin/sh
# Raises the patch version and build number in pubspec.yaml and writes lib/version.dart.
# Runs on every `make install`, so each app in /Applications has its own number.
set -e
cd "$(dirname "$0")/.."

current=$(sed -n 's/^version: //p' pubspec.yaml)
name=${current%+*}
build=${current#*+}
major=${name%%.*}
rest=${name#*.}
minor=${rest%%.*}
patch=${rest#*.}
next="$major.$minor.$((patch + 1))+$((build + 1))"

sed -i '' "s/^version: .*/version: $next/" pubspec.yaml
printf "/// Written by tool/bump_version.sh on every install; do not edit by hand.\nconst appVersion = '%s';\nconst appBuild = %s;\n" \
  "${next%+*}" "${next#*+}" > lib/version.dart
echo "GIT Watcher $next"

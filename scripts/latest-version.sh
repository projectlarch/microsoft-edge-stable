#!/bin/sh
# Print the newest microsoft-edge-stable version in Microsoft's repository, e.g. 142.0.3595.80.
set -eu

sh "$(dirname "$0")/add-edge-repo.sh"

version=$(dnf -q repoquery --refresh --latest-limit=1 --arch x86_64 \
  --qf '%{version}\n' microsoft-edge-stable 2>/dev/null | tail -n 1)

case $version in
  [0-9]*.[0-9]*) echo "$version" ;;
  *) echo "could not read the microsoft-edge-stable version (got '$version')" >&2; exit 1 ;;
esac

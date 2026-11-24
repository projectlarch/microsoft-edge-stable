# Microsoft Edge Stable AppImage

Unofficial AppImage of [Microsoft Edge](https://www.microsoft.com/edge) Stable for x86_64 Linux. It is
Microsoft's own `microsoft-edge-stable` RPM, repacked unchanged. This project is not affiliated with
Microsoft, and Edge stays under Microsoft's license terms.

## Install

Download `Microsoft-Edge-Stable-<version>-x86_64.AppImage` from the
[latest release](https://github.com/projectlarch/microsoft-edge-stable/releases/latest), make it
executable and run it:

```sh
chmod +x Microsoft-Edge-Stable-*-x86_64.AppImage
./Microsoft-Edge-Stable-*-x86_64.AppImage
```

You can also install it from [Sawmill](https://github.com/projectlarch/sawmill). Each AppImage carries
update information (`gh-releases-zsync`), so AppImageUpdate can update it in place too.

You need:
- **FUSE**, to run AppImages (`fuse` / `libfuse2`).
- **Edge's usual system libraries**: nss, gtk3, alsa-lib, libdrm, mesa and so on. The AppImage is "thin"
  and uses the host's libraries, which any desktop distribution has.
- **Unprivileged user namespaces.** An AppImage can't use a setuid helper, so the sandbox helper is
  removed and Edge uses its user-namespace sandbox. On Ubuntu 24.04 and later, AppArmor can block
  user namespaces for unconfined programs. If Edge won't start there, allow them, for example with an
  AppArmor profile for the AppImage.

## How it works

`.github/workflows/build.yml` runs every day at 05:17 UTC in a `fedora:latest` container:

1. `scripts/latest-version.sh` adds Microsoft's yum repository
   (`scripts/add-edge-repo.sh`, `https://packages.microsoft.com/yumrepos/edge`, GPG-checked) and reads
   the newest `microsoft-edge-stable` version.
2. If that version is newer than the latest release here (by `sort -V`), or there's no release yet,
   `scripts/build-appimage.sh <version>` runs these steps:
   - downloads the RPM and checks its Microsoft signature (`rpm -K`)
   - unpacks `/opt/microsoft/msedge`
   - drops Microsoft's cron repository script and the setuid sandbox helper
   - adds `AppRun`, the desktop file and the icon
   - packs everything with `appimagetool`
3. A release is published, tagged with exactly the repository version (for example `158.0.4370.33`).
   It contains:
   - `Microsoft-Edge-Stable-<version>-x86_64.AppImage`
   - the matching `.zsync` file
   - `SHA256SUMS`

To rebuild by hand, go to Actions → Build → Run workflow. Turn on **force** to rebuild the current version
and replace its release files.

GitHub turns off scheduled workflows after 60 days without activity in the repository. If that happens,
turn the workflow back on under Actions.

## Build locally

```sh
docker run --rm -v "$PWD":/repo:Z -w /repo registry.fedoraproject.org/fedora:latest \
  sh -c 'sh scripts/build-appimage.sh "$(sh scripts/latest-version.sh)"'
ls dist/
```

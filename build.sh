#!/usr/bin/env bash
# ============================================================================
#  CyberOS ISO builder
#    1. builds the AUR packages listed in aur/packages.txt into repo/ (as your user)
#    2. runs mkarchiso (as root) with profile/  →  out/cyberos-YYYY.MM.DD-x86_64.iso
#
#  Signing:   --sign-key <KEYID>  sign the [cyberos] repo; required for release builds
#
#  work/ (AUR build trees + mkarchiso's scratch dir) is the biggest thing this
#  leaves on disk -- a full AUR set can run several GB. On success you're asked
#  whether to delete it; --keep-work/--purge-work skip that prompt (e.g. CI).
#  repo/ (the finished packages) and out/ (the ISO) are never touched by this.
#
#  Requirements (on an Arch host):  sudo pacman -S archiso base-devel git
#  Packet Tracer: drop CiscoPacketTracer_*_Ubuntu_64bit.deb (from netacad.com) into aur/
# ============================================================================
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO="$ROOT/repo"; WORK="$ROOT/work"; OUT="$ROOT/out"; PROFILE="$ROOT/profile"

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

SKIP_AUR=0; ONLY_AUR=0; SIGN_KEY=; KEEP_WORK=
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-aur)   SKIP_AUR=1; shift;;
    --only-aur)   ONLY_AUR=1; shift;;
    --clean)      sudo rm -rf "$WORK"; shift;;
    --keep-work)  KEEP_WORK=1; shift;;
    --purge-work) KEEP_WORK=0; shift;;
    --sign-key)   SIGN_KEY=${2:-}; shift 2;;
    # Print the whole leading comment block, so help cannot drift out of sync
    # with the header the way a hardcoded line range does.
    -h|--help)  awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "$0"; exit 0;;
    *) die "unknown option $1";;
  esac
done

[[ $EUID -ne 0 ]] || die "run build.sh as a normal user; it calls sudo where needed"
command -v mkarchiso >/dev/null || die "archiso not installed:  sudo pacman -S archiso"
command -v makepkg   >/dev/null || die "base-devel not installed: sudo pacman -S base-devel git"

# ------------------------------------------------------------------ 1. AUR
if [[ $SKIP_AUR -eq 0 ]]; then
  mkdir -p "$REPO" "$WORK/aur"
  while read -r pkg; do
    [[ -z $pkg || $pkg == \#* ]] && continue
    msg "AUR: $pkg"
    d="$WORK/aur/$pkg"
    if [[ -f $ROOT/aur/$pkg/PKGBUILD ]]; then
      mkdir -p "$d"; cp -f "$ROOT/aur/$pkg"/* "$d/"          # local PKGBUILD
    elif [[ -d $d/.git ]]; then
      # makepkg rewrites pkgver= in a VCS PKGBUILD, which leaves the clone dirty,
      # and `git pull` then refuses -- on a rebase-by-default config it refuses
      # outright. This clone is a disposable build cache, so take upstream's copy
      # rather than trying to merge into it. Untracked src/ and pkg/ are left
      # alone so makepkg can reuse them.
      git -C "$d" fetch -q origin
      git -C "$d" reset --hard -q FETCH_HEAD
    else
      git clone -q "https://aur.archlinux.org/$pkg.git" "$d"
    fi
    if [[ $pkg == packettracer ]]; then
      deb=$(ls "$ROOT"/aur/CiscoPacketTracer_*_Ubuntu_64bit.deb 2>/dev/null | head -1 || true)
      [[ -n $deb ]] || die "Packet Tracer: put CiscoPacketTracer_*_Ubuntu_64bit.deb from https://www.netacad.com into $ROOT/aur/"
      cp -f "$deb" "$d/"
      # Cisco re-releases the same version with different checksums; trust our local copy.
      (cd "$d" && updpkgsums >/dev/null 2>&1 || true)
    fi
    (cd "$d" && makepkg -sf --noconfirm --needed)
    cp -f "$d"/*.pkg.tar.zst "$REPO/"
  done < "$ROOT/aur/packages.txt"
  msg "Creating local repo"
  rm -f "$REPO"/cyberos.db* "$REPO"/cyberos.files* "$REPO"/*.sig
  if [[ -n $SIGN_KEY ]]; then
    for pkg in "$REPO"/*.pkg.tar.zst; do
      gpg --detach-sign --local-user "$SIGN_KEY" --yes "$pkg"
    done
    repo-add -q --sign --key "$SIGN_KEY" "$REPO/cyberos.db.tar.gz" "$REPO"/*.pkg.tar.zst
  else
    repo-add -q "$REPO/cyberos.db.tar.gz" "$REPO"/*.pkg.tar.zst
  fi
fi
[[ $ONLY_AUR -eq 1 ]] && exit 0

[[ -f $REPO/cyberos.db ]] || die "repo/ is empty — run without --skip-aur first"

# ------------------------------------------------------------------ 2. ISO
msg "Generating profile/pacman.conf"
if [[ -n $SIGN_KEY ]]; then
  SIGLEVEL="Required DatabaseRequired TrustedOnly"
else
  SIGLEVEL="Optional TrustAll"
  cat >&2 <<'WARN'

  WARNING: building with an UNSIGNED [cyberos] repo.

  This is fine for a local development build. It is not fine for anything a
  student installs: pass --sign-key <KEYID> to sign the repo, and see
  docs/SPEC.md §5.5. Signing needs the department key -- decision D2.

WARN
fi
sed -e "s|@REPO_DIR@|$REPO|" -e "s|@CYBEROS_SIGLEVEL@|$SIGLEVEL|" \
  "$PROFILE/pacman.conf.in" > "$PROFILE/pacman.conf"

msg "Building ISO with mkarchiso (needs root)"
mkdir -p "$OUT" "$WORK"
LOG="$WORK/build.log"

# A stale work dir from a previous package set makes mkarchiso fail in ways that
# look like a profile bug. It is a scratch dir, so start clean.
if [[ -d $WORK/iso ]]; then
  msg "Removing the previous work directory"
  sudo rm -rf "$WORK/iso"
fi

# Tee to a log: without one, a failed build leaves nothing to read afterwards
# but scrollback.
echo "   logging to $LOG"
set -o pipefail
if ! sudo mkarchiso -v -w "$WORK/iso" -o "$OUT" "$PROFILE" 2>&1 | tee "$LOG"; then
  echo
  die "mkarchiso failed. Last 20 lines of $LOG:
$(tail -20 "$LOG")"
fi
sudo chown "$USER:$USER" "$OUT"/*.iso
msg "ISO ready:"; ls -lh "$OUT"/*.iso
ISO=$(ls -t "$OUT"/*.iso | head -1)
echo "Test it:  ./test-vm.sh $ISO"

# ------------------------------------------------------------------ 3. work/ cleanup
# work/aur holds each AUR package's git clone plus its src/ and pkg/ build trees
# (kept so a rebuild can skip re-downloading/recompiling -- onlyoffice-bin and
# vscode-bin alone can be several GB); work/iso is mkarchiso's own scratch tree.
# Neither is needed once repo/ has the finished packages and out/ has the ISO,
# but keeping them makes the next build much faster, so ask rather than assume.
if [[ -d $WORK ]]; then
  SIZE=$(sudo du -sh "$WORK" 2>/dev/null | cut -f1)
  if [[ -z $KEEP_WORK ]]; then
    if [[ -t 0 ]]; then
      read -rp "Delete build/work directory ($WORK, $SIZE -- next build re-downloads/recompiles any AUR packages)? [y/N] " reply
      [[ $reply =~ ^[Yy] ]] && KEEP_WORK=0 || KEEP_WORK=1
    else
      msg "Non-interactive: keeping $WORK ($SIZE). Pass --purge-work to delete it automatically."
      KEEP_WORK=1
    fi
  fi
  if [[ $KEEP_WORK -eq 0 ]]; then
    msg "Removing $WORK"
    sudo rm -rf "$WORK"
  fi
fi

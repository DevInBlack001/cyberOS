#!/usr/bin/env bash
# Runs inside the chroot during `mkarchiso` (after packages + airootfs overlay are in place).
set -euo pipefail

# locales (mkarchiso does not run locale-gen)
sed -i 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# live user home from /etc/skel
mkdir -p /home/student
cp -rT /etc/skel /home/student
mkdir -p /home/student/{Desktop,Documents,Downloads,Pictures,Projects}
chown -R 1000:1000 /home/student
chmod 750 /home/student

# root gets the same shell config
cp -rT /etc/skel /root
chmod 750 /root

# VS Code: sane defaults + "code" points at the Microsoft build (visual-studio-code-bin)
mkdir -p /etc/skel/.config/Code/User /home/student/.config/Code/User
cat > /etc/skel/.config/Code/User/settings.json <<'JSON'
{
  "workbench.colorTheme": "Default Dark Modern",
  "editor.fontFamily": "'JetBrainsMono Nerd Font', monospace",
  "editor.fontSize": 14,
  "editor.fontLigatures": true,
  "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font",
  "window.titleBarStyle": "custom",
  "telemetry.telemetryLevel": "off",
  "update.mode": "none"
}
JSON
cp /etc/skel/.config/Code/User/settings.json /home/student/.config/Code/User/
chown -R 1000:1000 /home/student/.config/Code

# Wireshark without root
groupadd -f wireshark || true
usermod -aG wireshark student || true

# Arch's stock mirrorlist ships with every Server line commented out, so both the
# live session and anything installed from it fail every sync with "no servers
# configured for repository". Enable the two worldwide CDN mirrors; students can
# narrow them down with reflector later.
sed -i -E 's@^#(Server = https://(fastly|geo)\.mirror\.pkgbuild\.com/.*)@\1@' /etc/pacman.d/mirrorlist
grep -q '^Server' /etc/pacman.d/mirrorlist || { echo 'no mirrors enabled in /etc/pacman.d/mirrorlist' >&2; exit 1; }

# Firewall: default-deny inbound, allow outbound. Set ENABLED here rather than
# running `ufw enable`, which tries to load rules into a kernel this chroot does
# not own. Lab exercises that need an inbound port open one explicitly, e.g.
#   sudo ufw allow 4444/tcp
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
grep -q '^ENABLED=yes' /etc/ufw/ufw.conf || { echo 'failed to enable ufw' >&2; exit 1; }
systemctl enable ufw.service >/dev/null 2>&1

# keep the live image lean (the empty sync dir stays, or pacman warns on every call)
rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* /root/.cache /home/student/.cache
mkdir -p /var/lib/pacman/sync

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

# keep the live image lean
rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* /root/.cache /home/student/.cache

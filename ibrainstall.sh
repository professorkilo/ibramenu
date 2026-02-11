#!/bin/bash
set -euo pipefail

######################################################################
# Title   : IBRAINSTALL Installer and Updater for IBRAMENU
# By      : Sycotix, DiscDuck, Taos15
# License : General Public License GPL-3.0-or-later
# Another fine product brought to you by IBRACORP™
######################################################################

# Install configuration (overridable for testing)
prefix_dir="${IBRAMENU_PREFIX:-/opt/ibracorp}"
ifolder="${IBRAMENU_INSTALL_ROOT:-${prefix_dir}/ibramenu}"
clone_source="${IBRAMENU_CLONE_SOURCE:-https://github.com/ibracorp/ibramenu.git}"
clone_branch="${IBRAMENU_CLONE_BRANCH:-main}"
skip_packages="${IBRAMENU_SKIP_PACKAGES:-0}"
skip_aliases="${IBRAMENU_SKIP_ALIASES:-0}"
skip_motd="${IBRAMENU_SKIP_MOTD:-0}"
profile_alias_file="/etc/profile.d/ibramenu.sh"
launcher_dir="${IBRAMENU_LAUNCHER_DIR:-/usr/local/bin}"

# Check for existing ibramenu folder and clean up if needed
if [ -d "$ifolder" ]; then
  rm -rf "$ifolder"
fi
mkdir -p "$ifolder"

# Clone ibramenu
if [ "$skip_packages" -ne 1 ]; then
  apt update
  apt install sudo curl git ruby ruby-dev build-essential -y
  gem install mdless --no-document

  # Install Docker if not already present
  if ! command -v docker >/dev/null 2>&1; then
    apt-get install ca-certificates curl gnupg lsb-release -y
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    groupadd docker 2>/dev/null || true
    usermod -aG docker "${SUDO_USER:-$USER}"
  fi
fi
git clone -b "$clone_branch" --single-branch "$clone_source" "$ifolder"
find "$ifolder" -type f -iname "*.sh" -exec chmod +x {} \;

# Install launchers into a directory on PATH
install_launcher() {
  local launcher_name="$1"
  local target_script="$2"

  mkdir -p "$launcher_dir"
  cat <<EOF | tee "${launcher_dir}/${launcher_name}" > /dev/null
#!/bin/bash
exec sudo "${target_script}" "\$@"
EOF
  chmod +x "${launcher_dir}/${launcher_name}"
}

install_launcher "ibramenu" "${ifolder}/ibramenu.sh"
install_launcher "ibraupdate" "${ifolder}/ibraupdate.sh"
install_launcher "ibrauninstall" "${ifolder}/ibrauninstall.sh"

# Add ibramenu as systemwide alias
if [ "$skip_aliases" -ne 1 ]; then
  sudo tee "$profile_alias_file" > /dev/null <<EOF
# IBRAMENU aliases loaded by /etc/profile for login shells.
alias ibramenu='sudo ${ifolder}/ibramenu.sh'
alias ibraupdate='sudo ${ifolder}/ibraupdate.sh'
alias ibrauninstall='sudo ${ifolder}/ibrauninstall.sh'
EOF
  sudo chmod 0644 "$profile_alias_file"
fi

# Include ibrafunc for all the awesome functions
if [ "$skip_motd" -ne 1 ]; then
  source "${ifolder}/ibrafunc.sh"
  ibramotd
  ibralogo
fi
if [[ -n ${1-} ]]
then
  if [ "$1" = all ]
  then
    cd "/opt/ibracorp/ibramenu/MenuOptions/Submenu Basic Install Steps/All Steps in One"
    "./All Steps in One.sh"
    reboot
  else
    msgbox "Type 'ibramenu' to launch IBRAMENU"
    msgbox "Type 'ibraupdate' to update"
    msgbox "Type 'ibrauninstall' to uninstall"
    msgbox "Please reboot after the first installation"
  fi
fi

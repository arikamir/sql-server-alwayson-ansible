#!/usr/bin/env bash
# Helper script to prepare the Ansible control node prerequisites described in
# allways-on-ansiblesetup.md. Creates a Python virtual environment, installs
# Ansible 8+, WinRM dependencies, and pulls the required Galaxy collections.

set -euo pipefail

ANSIBLE_VERSION="${ANSIBLE_VERSION:->=8.0.0}"
VENV_PATH="${VENV_PATH:-.venv}"
GALAXY_REQUIREMENTS=(
  "ansible.windows:2.8.0"
  "community.windows:2.4.0"
  "oatakan.windows_cluster:1.0.3"
  "oatakan.windows_sql_server:1.0.5"
  "lowlydba.sqlserver:2.6.1"
)

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required. Install Python 3.9+ before running this script." >&2
  exit 1
}

if [[ ! -d "${VENV_PATH}" ]]; then
  python3 -m venv "${VENV_PATH}"
fi

# shellcheck disable=SC1090
source "${VENV_PATH}/bin/activate"

python -m pip install --upgrade pip
pip install "ansible${ANSIBLE_VERSION}" pywinrm pywinrm[credssp] pypsrp

for collection in "${GALAXY_REQUIREMENTS[@]}"; do
  ansible-galaxy collection install "${collection}"
done

cat <<'INSTRUCTIONS'
Prerequisites complete.

Next steps (manual):
  1. Configure WinRM HTTPS listeners on each Windows host using the official Ansible winrm.ps1 helper.
  2. Ensure DNS, firewall ports (UDP/TCP 3343, TCP 1433, TCP 5022, TCP 5986), and static IP reservations are in place.
  3. Populate inventory/group variable credentials using Ansible Vault before running site.yml.
INSTRUCTIONS

#!/bin/bash
# Make sure this file uses LF line endings when copied to Linux
# Controller setup script for Inference Infrastructure

set -e

echo "====================================================================="
echo "                    Inference Controller Setup"
echo "====================================================================="
echo ""
echo "This script will set up the controller machine with Ansible and all"
echo "necessary dependencies to manage your inference infrastructure."
echo ""

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
  echo "This script should NOT be run as root. Please run as a regular user."
  exit 1
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Check for sudo access
echo "Checking sudo access..."
if ! sudo -v; then
  echo "ERROR: You need sudo privileges to install packages. Please add your user to sudoers."
  exit 1
fi

echo "Updating package lists..."
sudo apt update

echo "Installing required packages..."
sudo apt install -y python3 python3-pip git openssh-client sshpass curl wget jq

echo "Installing Ansible..."
if command_exists ansible; then
  echo "Ansible is already installed. Checking version..."
  ansible --version
else
  echo "Installing Ansible via pip3..."
  pip3 install --user ansible
  
  # Add local pip binaries to PATH if needed
  if ! command_exists ansible; then
    echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
    export PATH=$PATH:$HOME/.local/bin
  fi
  
  echo "Ansible installed:"
  ansible --version
fi

# Create directories if they don't exist
echo "Creating working directories..."
mkdir -p ~/inference
cd ~/inference

# Clone or update repository if provided
if [ -n "$1" ]; then
  REPO_URL="$1"
  echo "Cloning repository: $REPO_URL"
  git clone "$REPO_URL" .
else
  echo "Creating default structure..."
  mkdir -p ansible/roles
  mkdir -p ansible/group_vars
  mkdir -p ansible/inventory
  mkdir -p ansible/templates
  
  # Create basic ansible.cfg
  cat > ansible/ansible.cfg << EOF
[defaults]
inventory = inventory.yml
host_key_checking = False
callbacks_enabled = profile_tasks
forks = 10
pipelining = True
timeout = 30

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o PreferredAuthentications=publickey

[privilege_escalation]
become = True
become_method = sudo
EOF

  # Create sample inventory.yml
  cat > ansible/inventory.yml << EOF
---
all:
  children:
    inference_nodes:
      hosts:
        # Add your inference nodes here
        # Example:
        # node1:
        #   ansible_host: 192.168.1.101
        #   ansible_user: shaun
      vars:
        ansible_python_interpreter: /usr/bin/python3
EOF
fi

# Check SSH key for Ansible
echo "Checking SSH key setup..."
if [ ! -f ~/.ssh/id_rsa ]; then
  echo "Generating SSH key for Ansible..."
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
  echo "SSH key generated. You will need to copy this to your target nodes."
  echo ""
  echo "Use the following command to copy your SSH key to each node:"
  echo "  ssh-copy-id -i ~/.ssh/id_rsa.pub user@hostname"
fi

# Install additional Python requirements for Ansible
echo "Installing Python requirements for Ansible..."
pip3 install --user jmespath netaddr passlib dnspython

echo "====================================================================="
echo "                    Setup Complete!"
echo "====================================================================="
echo ""
echo "Your Ansible controller is now set up."
echo ""
echo "Next steps:"
echo "  1. Edit ansible/inventory.yml to add your inference nodes"
echo "  2. Copy your SSH key to each node: ssh-copy-id -i ~/.ssh/id_rsa.pub user@hostname"
echo "  3. Test Ansible connectivity: cd ansible && ansible all -m ping"
echo "  4. Run playbooks: ansible-playbook site.yml"
echo ""
echo "Happy automating!"

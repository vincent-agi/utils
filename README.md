# Linux Server Security Toolkit

This repository provides a suite of interactive bash scripts designed to help configure and enhance the security of Linux servers. Each script guides the user through important security steps, making the process accessible and reliable for both beginners and experienced administrators.

## Purpose

The goal of this toolkit is to simplify and automate the setup of essential security features on Linux servers, reducing the risk of misconfiguration and improving overall server integrity.

## Scripts Overview

### 1. ssh-key-setup-and-server-config.sh
**What does this script do?**
- Automates the creation of a secure SSH key pair.
- Transfers the public key to a remote server.
- Updates the local SSH configuration for easy access.
- Optionally executes additional security scripts on the remote server.

**Why should you use it?**
- Ensures strong authentication for SSH access.
- Reduces the risk of brute-force attacks by eliminating password logins.
- Simplifies SSH management and improves convenience.

### 2. sshd-secure-config.sh
**What does this script do?**
- Hardens the SSH server configuration.
- Changes the default SSH port.
- Disables password authentication.
- Enables key-based authentication.
- Restarts the SSH service to apply changes.

**Why should you use it?**
- Protects your server from common SSH attacks.
- Makes unauthorized access more difficult.
- Enforces best practices for SSH security.

### 3. fail2ban-setup-interactive.sh
**What does this script do?**
- Installs and configures fail2ban interactively.
- Allows customization of ban time, retry limits, monitored services, and notification settings.
- Validates fail2ban status and configuration.
- Enables fail2ban after explicit user approval.

**Why should you use it?**
- Provides automated protection against brute-force and suspicious login attempts.
- Helps prevent server compromise by blocking malicious IPs.
- Offers flexible configuration to suit your needs.

## Usage Instructions

1. Clone the repository to your local machine:
   ```bash
   git clone <repo-url>
   cd <repo-folder>
   ```

2. Make the scripts executable:
   ```bash
   chmod +x *.sh
   ```

3. Start with the SSH key setup script:
   ```bash
   ./ssh-key-setup-and-server-config.sh
   ```
   - Follow the interactive prompts to generate your SSH key and configure your server.
   - At the end, you can choose to run additional security scripts (SSH hardening or fail2ban setup) on your remote server.

4. You can also run the other scripts individually if needed:
   ```bash
   ./sshd-secure-config.sh
   ./fail2ban-setup-interactive.sh
   ```
   - Each script will guide you through its configuration interactively.

## Requirements
- Bash shell
- SSH access to the remote server
- sudo privileges on the remote server
- Debian/Ubuntu-based remote server (for fail2ban installation)

## License
This toolkit is provided as-is, without warranty. Use at your own risk.

---
For questions or suggestions, please open an issue in the repository.

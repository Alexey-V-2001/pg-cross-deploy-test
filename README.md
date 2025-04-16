# PG Cross-Deploy: Dual-Stack Auto-Installer

## Technical Specification

### Objective
Develop a console application for automated PostgreSQL installation on the least loaded server from a list, including access configuration and functionality verification.

---

### Input Data
- Two servers:
  - OS: Debian and AlmaLinux (CentOS).
  - Access: Root access via SSH using a private key (the public key is already added to the servers).

---

### Application Requirements
1. **Launch Parameters**:
   - Accepts IP addresses or server names as a comma-separated string (e.g., `192.168.1.10,192.168.1.20`).
   - Outputs the status of each operation (success/error).

2. **Functionality**:
   - Connect to servers via SSH.
   - Select the target server with the lowest load (based on the 5-minute load average).
   - Install PostgreSQL according to the server's OS (Debian/AlmaLinux).
   - Basic PostgreSQL configuration:
     - Allow external connections (listen on all interfaces).
     - Create a user `student` with access only from the second server's IP.
   - Firewall configuration (open port 5432).
   - Optional automatic database health check via the `SELECT 1` query.

3. **Technical Requirements**:
   - Development languages: **Python**, **Bash**, or **Ansible**.
   - GitHub repository with setup instructions and usage examples.
   - Error handling and clear operation status messages.

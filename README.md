# PG Cross-Deploy: Dual-Stack Auto-Installer

## Technical Specification

### Objective
Develop a console application for automated PostgreSQL installation on the least loaded server from a list, including access configuration and functionality verification.

### Input Data
- Two servers:
  - OS: Debian and AlmaLinux (CentOS).
  - Access: Root access via SSH using a private key (the public key is already added to the servers).

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

---

## How to Run  

To start testing, run the `docker-compose up` command in the repository folder. The entire process will be displayed in the logs.  
If manual script execution is required, navigate to the `./app` directory. Run the console script `deploy_pg_on_server.sh` using the command:  
`./deploy_pg_on_server.sh ip1,ip2`.  
The script will select the least loaded server from the two and deploy PostgreSQL on it, performing the necessary tests.  

### Example Usage

#### Preparing the environment. Setting up keys on servers (containers)

![Setup SSH keys](https://raw.githubusercontent.com/Alexey-V-2001/pg-cross-deploy-test/refs/heads/assets/assets/setup_ssh_keys.png)

Next, the main script `./app/deploy_pg_on_server.sh debian,almalinux` is executed.

#### Scenario 1. The least loaded server is `almalinux`

Executing the main script `deploy_pg_on_server.sh`. Installing PostgreSQL on AlmaLinux:
![Almalinux logs](https://raw.githubusercontent.com/Alexey-V-2001/pg-cross-deploy-test/refs/heads/assets/assets/logs_almalinux.png)

#### Scenario 2. The least loaded server is `debian`

Executing the main script `deploy_pg_on_server.sh`. Installing PostgreSQL on Debian:
![Debian logs](https://raw.githubusercontent.com/Alexey-V-2001/pg-cross-deploy-test/refs/heads/assets/assets/logs_debian.png)

---

## Implementation Process 
***Description of the experience gained, what questions arose, general impressions, what difficulties there were, etc.***

### How to Run Tests?

Docker and Docker Compose were selected as the testing environment.  

### How to Simplify Testing?  

To maximize simplicity, I proposed making testing executable via a single command (`docker-compose up`).  
**All tests will run within a single orchestrated setup (docker-compose.yml)** with three services:  
   - `s0` – source server initiating the script;  
   - `s1` – Server 1 running Debian OS;  
   - `s2` – Server 2 running AlmaLinux (CentOS) OS.  
To avoid SSH key management overhead, **keys will be automatically generated and configured between services during the first orchestration startup (setup_ssh_keys.sh)**.  

### Using Service Names Instead of IP Addresses

While the technical specification required using IP addresses, we opted for Docker service names to comply with [official Docker documentation](https://docs.docker.com/compose/how-tos/networking/), improve reliability, and avoid network limitations in Windows environments with virtualization layers (Hyper-V/WSL2). For example, on Windows, accessing containers by IP sometimes caused `Name or service not known` errors, whereas service names worked flawlessly.  

Documentation excerpt:  
> "Each container can now look up the service name `web` or `db` and get back the appropriate container's IP address. ... If you update a service via `docker compose up`, the old container is replaced, and the new one joins the network with a new IP but the same name. Running containers can resolve the name to the new address, while the old IP becomes invalid.  
> ...  
> **Tip: Always reference containers by name instead of IP. Otherwise, you’ll need to continuously update IP addresses.**"  

***To demonstrate the script's functionality**, an implementation using IP addresses was ultimately added.*

### PostgreSQL Management Challenges  

The primary issue and cornerstone of this mini-project was the inability to use `systemd` utilities. Since Docker employs lightweight images that do not run with `systemd`, all operations (starting, restarting, initializing the database, stopping, etc.) had to be performed using PostgreSQL’s built-in tools. Personally, I found `pg_ctl` rather finicky - it wouldn’t simply output an error, forcing me to locate and read log files. Debian deserves special mention here: its `/usr/bin/pg_ctl` spawned a parallel process alongside the main `postgresql` service, resulting in server process duplication.  

### Miscellaneous  

Most problems stemmed from a mismatch between "expectation and reality." Here are a few examples:  
- **Missing Familiar Commands in Docker**:  
   - AlmaLinux lacked the `service` utility for managing services (though Debian, notably, includes it).  
   - The absence of `systemctl` was a particular headache. While this is inherent to Docker, it significantly increased development complexity and duration.  
   - etc.  
- **Certain Commands Failed on Re-execution, Requiring Complex Logic**:  
   - Re-running the main script, `deploy_pg_on_server.sh`, triggered database initialization even when the DB already existed. This necessitated adding data checks and conditional initialization.  
   - Starting PostgreSQL in AlmaLinux: If the DBMS was already running, it returned an exit code 1, crashing Ansible. A dedicated script was written to handle the DBMS’s current status. A simple `ignore_errors` would’ve been a poor workaround.  
   - etc.  
- **Missing Basic Utilities (e.g., `nano`, `netcat`, `findutils`, `iproute`)**:  
   - This is more of a lightweight-distro inconvenience; such cases are rare in practice.  
- **The Joys of Shell Scripting**:  
   - Writing `sh` scripts remains a unique "delight." Despite my experience, conditional logic, escaping, multiline quoted commands, and the like are hard to rival (I’d argue even university-level Assembly felt easier at times-ha ha).

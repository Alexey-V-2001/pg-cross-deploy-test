import os
import re
import paramiko
import sys
import json

LOAD_PERIOD = 15

def connect_server(hostname, key_path=None):
    """
    Connecting to the server via SSH.
    """
    ssh_client = paramiko.SSHClient()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        if key_path is None:
            default_key_path = os.path.expanduser('~/.ssh/id_rsa')
            if os.path.exists(default_key_path):
                key_path = default_key_path
            else:
                ssh_client.connect(hostname=hostname)
                return ssh_client
        
        ssh_client.connect(hostname=hostname, key_filename=key_path)
        return ssh_client

    except paramiko.ssh_exception.NoValidConnectionsError:
        print(f"Error connecting to {hostname}: Invalid path to private key or key is invalid.")
        return None
    except paramiko.AuthenticationException:
        print(f"Error connecting to {hostname}: Incorrect credentials.")
        return None
    except Exception as e:
        print(f"Error connecting to {hostname}: {str(e)}")
        return None

def get_load_average(ssh_client, interval):
    """
    Gets the average server load for the specified interval.
    """    
    try:
        stdin, stdout, stderr = ssh_client.exec_command('cat /proc/loadavg')
        output = stdout.read().decode().strip()
        if not output:
            print("Error: empty output from command /proc/loadavg")
            return None
        
        parts = output.split()
        if len(parts) < 3:
            print("Error: Unexpected output format /proc/loadavg")
            return None
        
        interval_map = {1: 0, 5: 1, 15: 2}
        load_avg_str = parts[interval_map[interval]]
        
        return float(load_avg_str)
    
    except Exception as e:
        print(f"Error getting average load: {e}")
        return None

def detect_os(ssh_client):
    """
    Detecting the server operating system via SSH.
    """
    try:
        stdin, stdout, stderr = ssh_client.exec_command('cat /etc/os-release')
        os_release = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')
        if error:
            return 'unknown'

        match = re.search(r'^ID\s*=\s*"?([^"\n]+)"?', os_release, re.MULTILINE)
        if match:
            os_id = match.group(1).lower()
            if os_id in ('almalinux', 'centos'):
                return 'almalinux'
            elif os_id == 'debian':
                return 'debian'
            else:
                return os_id
        else:
            return 'unknown'
    except Exception:
        return 'unknown'


def get_ip_address(ssh_client):
    """
    Getting the server IP address via SSH.
    """
    try:
        stdin, stdout, stderr = ssh_client.exec_command("hostname -I | awk '{print $1}'")
        ip = stdout.read().decode('utf-8').strip()
        return ip
    except Exception:
        return None

def main():
    if len(sys.argv) != 2:
        print(f"Usage: python3 {sys.argv[0]} \"host1,host2\"")
        return

    servers = sys.argv[1].split(',')
    server_info_list = []

    for server in servers:
        server = server.strip()
        
        ssh = connect_server(server)
        if not ssh:
            continue
            
        os_type = detect_os(ssh)
        if os_type == "unknown":
            ssh.close()
            continue

        load_avg = get_load_average(ssh, LOAD_PERIOD)
        os = detect_os(ssh)
        ip = get_ip_address(ssh)
        
        if not all([os, ip, load_avg is not None]):
            ssh.close()
            continue
            
        server_info_list.append({
            'os': os,
            'ip': ip,
            'load': load_avg,
        })
        
        ssh.close()

    if len(server_info_list) < 2:
        print("Not enough servers with complete data (2 required)")
        return

    # Sort servers by load (ascending)
    sorted_servers = sorted(server_info_list, key=lambda x: x['load'])[:2]
    
    result = {
        sorted_servers[0]['os']: [sorted_servers[0]['ip'], sorted_servers[0]['load']],
        sorted_servers[1]['os']: [sorted_servers[1]['ip'], sorted_servers[1]['load']]
    }
    
    # Output the result in JSON format for easy processing in bash (order is saved)
    print(json.dumps(result, indent=4, ensure_ascii=False))

if __name__ == "__main__":
    main()

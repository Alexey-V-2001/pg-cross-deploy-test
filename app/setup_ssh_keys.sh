#!/bin/bash

# SSH File Paths
SSH_DIR="/root/.ssh"
PRIVATE_KEY_FILE="$SSH_DIR/id_rsa"

# Generate keys if they don't exist
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    mkdir -p "$SSH_DIR"
    ssh-keygen -t rsa -b 4096 -N "" -f "$PRIVATE_KEY_FILE"
fi

# Splitting a string of IP addresses into an array
IFS=',' read -ra IPS <<< "$TARGET_IPS"

for ip in "${IPS[@]}"; do
    echo "Setting up connection to $ip"
    
    user=$(jq -r ".servers[] | select(.address == \"$ip\") | .user" servers.json)
    password=$(jq -r ".servers[] | select(.address == \"$ip\") | .password" servers.json)
    real_ip=$(getent hosts "$ip" | awk '{print $1}')

    if [ -z "$user" ] || [ -z "$password" ]; then
        echo "Error: No credentials found for $ip" >&2
        exit 1
    fi

    ssh-keyscan -H "$ip" "$real_ip" >> ~/.ssh/known_hosts 2>/dev/null
    
    for target in "$ip" "$real_ip"; do
        if [[ "$ip" == "$real_ip" ]]; then
            continue
        fi
        
        if ! sshpass -p "$password" ssh \
            -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=~/.ssh/known_hosts \
            "$user@$target" "grep -qF '$(cat ~/.ssh/id_rsa.pub)' ~/.ssh/authorized_keys" 2>/dev/null; then

            echo "The key is missing. Copying..."
            sshpass -p "$password" ssh-copy-id -f -o StrictHostKeyChecking=accept-new "$user@$target"
        else
            echo "The key for $target already exists."
        fi
    done
   
    echo "Address of source container: $(hostname -I)"
    ssh $user@$ip -p 22 'echo "Address of target container: $(hostname -I)"'
    
    echo "---"
done
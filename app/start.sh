#!/bin/bash

cd /root/app

export TARGET_IPS=$(jq -r '.servers[].address' servers.json | paste -sd "," -)
echo "=== Waiting for SSH servers to start: ${TARGET_IPS} ==="

IFS=',' read -ra IPS <<< "$TARGET_IPS"

for ip in "${IPS[@]}"; do
    echo "Checking $ip"

    if ! timeout 30 bash -c "until nc -z -w 2 $ip 22; do sleep 1; done"; then
        echo "Timeout reached for $ip"
        exit 1
    fi

    echo "SSH $ip is available"
done

echo "=== Configuring SSH keys ==="
./setup_ssh_keys.sh

echo "=== Run the main script ==="

./deploy_pg_on_server.sh $TARGET_IPS

# Keep the container active
tail -f /dev/null

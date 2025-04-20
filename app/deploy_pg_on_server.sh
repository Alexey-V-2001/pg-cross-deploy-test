#!/bin/bash

BACK_DIR=$(pwd)

cd ~/app

TARGET_IPS=$1

if [ -d "app_environment" ]; then
    echo "Virtual environment already exists."
else
    echo "Creating a new virtual environment..."
    python3 -m venv app_environment
fi

if [ ! -f "app_environment/bin/activate" ]; then
    echo "Error: activate file not found. Recreating virtual environment..."
    rm -rf app_environment
    python3 -m venv app_environment
fi

echo "Activating virtual environment..."
source app_environment/bin/activate

if [ -n "$VIRTUAL_ENV" ]; then
    echo "Virtual environment activated."
else
    echo "Error: Failed to activate virtual environment."
    exit 1
fi

echo "Installing/updating dependencies of python scrtipts..."
pip install -r requirements.txt -I

echo "Running..."
result=$(python3 ./server_load.py $TARGET_IPS)

os1=$(echo "$result" | jq -r 'keys[0]')
ip1=$(echo "$result" | jq -r '.[keys[0]][0]')
load1=$(echo "$result" | jq -r '.[keys[0]][1]')

os2=$(echo "$result" | jq -r 'keys[1]')
ip2=$(echo "$result" | jq -r '.[keys[1]][0]')
load2=$(echo "$result" | jq -r '.[keys[1]][1]')

ansible-playbook -i ./ansible/inventory.ini ./ansible/ansible_install_postgresql_$os1.yml -e "allowed_ip=$ip1"

if ssh root@$os2 -p 22 'grep -qi "^ID=debian" /etc/os-release'; then
    ssh root@$os2 -p 22 "apt-get update && apt-get install -y postgresql-15"
else
    ssh root@$os2 -p 22 "dnf update && dnf install -y postgresql-server-13.20"
fi

echo "Test query"
ssh root@$os2 -p 22 "PGPASSWORD='studentpass' psql -h $ip1 -U student -d postgres -c 'SELECT 1;'"

echo "Deactivating virtual environment..."
deactivate

cd $BACK_DIR
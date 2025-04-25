#!/bin/bash

BACK_DIR=$(pwd)

cd ~/app

TARGET_IPS=$1

# ======== Formatted echo functions =======
# echo_i - echo information
function echo_i() {
    echo -e "\033[1;35m$1\033[0m"
}

# echo_s - echo success
function echo_s() {
    echo -e "\033[42m\033[1;90m${1}\033[0m"
}

# echo_w - echo warning
function echo_w() {
    echo -e "\033[1;30;43m$1\033[0m"
}

# echo_e - echo error
function echo_e() {
    echo -e "\033[1;37m\033[41m$1\033[0m"
}
# =========================================

if [ -d "app_environment" ]; then
    echo_i "Virtual environment already exists."
else
    echo_i "Creating a new virtual environment..."
    python3 -m venv app_environment
fi

if [ ! -f "app_environment/bin/activate" ]; then
    echo_w "Warning: activate file not found. Recreating virtual environment..."
    rm -rf app_environment
    python3 -m venv app_environment
fi

echo_i "Activating virtual environment..."
source app_environment/bin/activate

if [ -n "$VIRTUAL_ENV" ]; then
    echo_s "Virtual environment activated."
else
    echo_e "Error: Failed to activate virtual environment."
    exit 1
fi

echo_i "Installing/updating dependencies of python scripts..."
if ! pip freeze | grep -q -f requirements.txt; then
    pip install -r requirements.txt -I
fi

echo_i "Get the least loaded server..."
result=$(python3 ./server_load.py $TARGET_IPS)

if [ $? -ne 0 ]; then
    echo_e "Error. Can't get servers load stats."
    exit 1
fi

echo_i "Deactivating virtual environment..."
deactivate

os1=$(echo "$result" | jq -r 'keys_unsorted[0]')
ip1=$(echo "$result" | jq -r '.[keys_unsorted[0]][0]')

os2=$(echo "$result" | jq -r 'keys_unsorted[1]')
ip2=$(echo "$result" | jq -r '.[keys_unsorted[1]][0]')

echo_s "The least loaded server is $os1 (${ip1})"

echo_i "Check if server 1, $os1 (${ip1}), have python3 installed..."
ssh root@$ip1 "command -v python3 >/dev/null && echo 'Python3 is already installed on $os1 (${ip1})' || {
        grep -qi '^ID=debian' /etc/os-release && { apt-get update; apt-get install -y python3; } || dnf install -y python3
    }"

if ! command -v ansible >/dev/null 2>&1; then
    echo_w "Ansible isn't installed! Installing..."
    apt-get update
    apt-get install -y ansible
fi

echo_i "Run Ansible playbook..."
ansible-playbook -i ./ansible/inventory.ini ./ansible/ansible_install_postgresql_$os1.yml -e "allowed_ip=$ip2"

if [ $? -ne 0 ]; then
    echo_e "Error in PostgreSQL setup process on server $os1 (${ip1})" >&2
    exit 1
fi

echo_i "Installing postgresql on second server to make a test query..."
if ssh root@$ip2 -p 22 'grep -qi "^ID=debian" /etc/os-release'; then
    ssh root@$ip2 -p 22 "apt-get update && apt-get install -y postgresql-15"
else
    ssh root@$ip2 -p 22 "dnf update && dnf install -y postgresql-server-13.20"
fi

echo_i "Making test query from server 2, $os2 (${ip2}), to server 1, $os1 (${ip1})..."
ssh root@$ip2 -p 22 "PGPASSWORD='studentpass' psql -h $ip1 -U student -d postgres -c 'SELECT 1;'"

if [ $? -eq 0 ]; then
    echo_s "[ SUCCESS ]"
    echo_s "Server 1, $os1 (${ip1}), is configured and ready to go!"
else
    echo_e "[ FAIL ]"
    echo_e "Something went wrong..."
fi

cd $BACK_DIR
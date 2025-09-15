#!/usr/bin/env python3

import os
import sys
import re
import yaml
from getpass import getpass
import ipaddress
from config import (
    mainnet_relay_options,
    holesky_relay_options,
    sepolia_relay_options,
    hoodi_relay_options,
    get_relay_urls,
    get_sync_urls
)

def validate_ip(ip):
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False

def get_boolean_input(prompt, default=False):
    while True:
        choice = input(f"{prompt} (yes/no) [{'yes' if default else 'no'}]: ").lower() or ('yes' if default else 'no')
        if choice in ['yes', 'y', 'true']:
            return "true"
        elif choice in ['no', 'n', 'false']:
            return "false"
        print("Please answer with yes or no")

def get_secure_password(prompt):
    while True:
        password = getpass(f"{prompt}: ")
        if len(password) < 8:
            print("Password must be at least 8 characters long")
            continue
        confirm = getpass("Confirm password: ")
        if password != confirm:
            print("Passwords don't match. Please try again")
            continue
        return password

def get_ssh_config():
    config = {}
    config["ansible_user"] = input("\nEnter SSH user [default: root]: ") or "root"
    config["ansible_ssh_private_key_file"] = input("Enter SSH private key path [default: ~/.ssh/id_rsa]: ") or "~/.ssh/id_rsa"
    config["ansible_port"] = input("Enter SSH port [default: 22]: ") or "22"
    return config

def get_deployment_type():
    while True:
        print("\nPlease select your deployment type:")
        print("1. Ethereum Node Only (No validator)")
        print("2. Single Validator Node with Lighthouse")
        print("3. Distributed Validator Node with Charon and Lodestar")
        
        choice = input("\nEnter your choice (1-3): ")
        if choice in ['1', '2', '3']:
            return int(choice)
        print("Invalid choice. Please select 1, 2, or 3")

def configure_ethereum_node():
    config = {}
    
    # Network configuration
    config["network"] = input("\nEnter network name (e.g., mainnet, hoodi) [default: hoodi]: ") or "hoodi"
    config["NETWORK_NAME"] = config["network"]
    
    # MEV configuration
    config["mev_boost_enabled"] = get_boolean_input("\nDo you want to enable MEV-Boost?")
    
    if config["mev_boost_enabled"] == "true":
        from config import get_relay_urls
        
        print("\nAvailable MEV-Boost relays for", config["network"])
        relay_options = {
            'mainnet': mainnet_relay_options,
            'holesky': holesky_relay_options,
            'sepolia': sepolia_relay_options,
            'hoodi': hoodi_relay_options
        }.get(config["network"].lower(), [])
        
        selected_relays = []
        for idx, relay in enumerate(relay_options, 1):
            print(f"{idx}. {relay['name']}")
            choice = get_boolean_input(f"Include {relay['name']} relay?", True)
            if choice == "true":
                selected_relays.append(relay['name'])
        
        if selected_relays:
            config["mev_boost_relays"] = get_relay_urls(config["network"], selected_relays)
        else:
            print("No relays selected. Using all available relays.")
            config["mev_boost_relays"] = get_relay_urls(config["network"])
    
    return config

def configure_single_validator():
    config = configure_ethereum_node()
    
    # Set validator client to Lighthouse
    config["validator_client"] = "lighthouse"
    
    # Add placeholder for validators
    config["validators"] = [{
        "public_key": "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "keystore_file": "keystore-example.json",
        "keystore_password": "replace_with_encrypted_password",
        "enabled": False
    }]
    
    return config

def configure_charon_validator():
    config = configure_ethereum_node()
    
    # Set validator client to Lodestar for Charon
    config["validator_client"] = "lodestar"
    
    # Charon-specific configuration
    print("\nCharon Distributed Validator Configuration:")
    config["is_leader"] = get_boolean_input("Is this node the Charon leader?", False)
    
    if config["is_leader"] == "true":
        config["charon_name"] = input("Enter Charon cluster name: ")
        num_validators = int(input("Enter number of validators in the cluster: "))
        config["charon_num_validators"] = num_validators
        
        print("\nYou will need to configure these after setup:")
        print("1. charon_enr_private_key")
        print("2. charon_operator_enrs")
        print("3. charon_fee_recipient_addresses")
        print("4. charon_withdrawal_addresses")
    
    # Add placeholder for validators
    config["validators"] = [{
        "public_key": "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "keystore_file": "keystore-example.json",
        "keystore_password": "replace_with_encrypted_password",
        "enabled": False
    }]
    
    return config

def main():
    print("Welcome to the Ethereum Staking Node Setup!")
    print("===========================================")
    
    # Get server information
    while True:
        server_ip = input("\nEnter your server IP address: ")
        if validate_ip(server_ip):
            break
        print("Invalid IP address format. Please try again.")
    
    # Get deployment type
    deployment_type = get_deployment_type()
    
    # Configure based on deployment type
    if deployment_type == 1:
        config = configure_ethereum_node()
    elif deployment_type == 2:
        config = configure_single_validator()
    else:  # deployment_type == 3
        config = configure_charon_validator()
    
    # Common configuration
    config["IP"] = server_ip
    config["GRAFANA_ADMIN_PASSWORD"] = get_secure_password("\nEnter Grafana admin password")
    config["cadvisor_enabled"] = "true"
    
    # Get SSH configuration
    ssh_config = get_ssh_config()
    config.update(ssh_config)
    
    # Telegram notifications (optional)
    enable_telegram = get_boolean_input("\nDo you want to set up Telegram notifications?", False)
    if enable_telegram == "true":
        config["telegram_bot_token"] = input("Enter Telegram bot token: ")
        config["telegram_chat_id"] = input("Enter Telegram chat ID: ")
    else:
        config["telegram_bot_token"] = ""
        config["telegram_chat_id"] = ""
    
    # Ensure host_vars directory exists
    os.makedirs('host_vars', exist_ok=True)
    
    # Save host-specific secrets file
    host_vars_file = f'host_vars/{server_ip}.yml'
    with open(host_vars_file, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    
    # Create inventory file
    inventory_content = f"""[ethereum_nodes]
{server_ip} ansible_port={ssh_config['ansible_port']}

[all:vars]
ansible_user={ssh_config['ansible_user']}
ansible_ssh_private_key_file={ssh_config['ansible_ssh_private_key_file']}
ansible_python_interpreter=/usr/bin/python3
"""
    with open('inventory', 'w') as f:
        f.write(inventory_content)
    
    print("\nConfiguration complete!")
    print("=======================")
    print(f"\nCreated files:")
    print(f"1. {host_vars_file} - Contains your node configuration")
    print("2. inventory - Contains your server information")
    print("\nNext steps:")
    
    if deployment_type == 1:
        print("Run the Ansible playbook to set up your Ethereum node:")
        print("   ansible-playbook -i inventory main.yml")
    elif deployment_type == 2:
        print("1. Add your validator keys to the host_vars configuration file")
        print("2. Run the Ansible playbook to set up your validator node:")
        print("   ansible-playbook -i inventory main.yml")
    else:  # deployment_type == 3
        print("1. Set up your Charon cluster:")
        print("   - Follow the Obol documentation to generate your ENR")
        print("   - Update the Charon configuration in your host_vars file")
        print("2. Add your validator keys to the host_vars configuration file")
        print("3. Run the Ansible playbook to set up your distributed validator node:")
        print("   ansible-playbook -i inventory main.yml")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""Interactive setup: writes host_vars/<server-name>.yml and an inventory file for main.yml.

Prompting, validation and re-asking on bad input are handled by click.
"""

import ipaddress
import os
import re

import click
import yaml

from config import RELAY_OPTIONS, get_relay_urls

NETWORKS = sorted(RELAY_OPTIONS)


def yes_no(prompt, default=False):
    """Ask a yes/no question.

    The playbooks compare these settings as the strings "true"/"false", so return those.
    """
    return "true" if click.confirm(prompt, default=default) else "false"


def ask(prompt, **kwargs):
    """Ask for a required text value and strip surrounding whitespace."""
    return click.prompt(prompt, value_proc=str.strip, **kwargs)


def _ip_address(value):
    try:
        return str(ipaddress.ip_address(value.strip()))
    except ValueError:
        raise click.BadParameter("Invalid IP address format. Please try again.")


def _server_name(value):
    value = value.strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]+", value):
        raise click.BadParameter("Use only letters, digits, '.', '_' and '-'.")
    return value


def _min_length(length):
    def check(value):
        if len(value) < length:
            raise click.BadParameter(f"Password must be at least {length} characters long")
        return value
    return check


def get_secure_password(prompt):
    return click.prompt(prompt, hide_input=True, confirmation_prompt=True,
                        value_proc=_min_length(8))


def get_ssh_config():
    return {
        "ansible_user": ask("\nEnter SSH user", default="root"),
        "ansible_ssh_private_key_file": ask("Enter SSH private key path", default="~/.ssh/id_rsa"),
        "ansible_port": click.prompt("Enter SSH port", default=22, type=click.IntRange(1, 65535)),
    }


def get_deployment_type():
    click.echo("\nPlease select your deployment type:")
    click.echo("1. Ethereum Node Only (No validator)")
    click.echo("2. Single Validator Node with Lighthouse")
    click.echo("3. Distributed Validator Node with Charon and Lodestar")
    return click.prompt("\nEnter your choice", type=click.IntRange(1, 3))


def configure_ethereum_node():
    config = {}

    # Network configuration
    network = click.prompt("\nEnter network name", default="hoodi",
                           type=click.Choice(NETWORKS, case_sensitive=False))
    config["network"] = network
    config["NETWORK_NAME"] = network  # keep both variables set and consistent

    # Charon is only used by distributed validators (configure_charon_validator turns it
    # on). Write it explicitly: the playbook's default is "true".
    config["charon_enabled"] = "false"

    # MEV configuration
    config["mev_boost_enabled"] = yes_no("\nDo you want to enable MEV-Boost?")

    if config["mev_boost_enabled"] == "true":
        click.echo(f"\nAvailable MEV-Boost relays for {network}")
        selected_relays = []
        for idx, relay in enumerate(RELAY_OPTIONS[network], 1):
            click.echo(f"{idx}. {relay['name']}")
            if yes_no(f"Include {relay['name']} relay?", True) == "true":
                selected_relays.append(relay['name'])

        if selected_relays:
            config["mev_boost_relays"] = get_relay_urls(network, selected_relays)
        else:
            click.echo("No relays selected. Using all available relays.")
            config["mev_boost_relays"] = get_relay_urls(network)

    return config


def configure_single_validator():
    config = configure_ethereum_node()

    # Set validator client to Lighthouse
    config["validator_client"] = "lighthouse"

    # Get withdrawal address
    config["withdrawal_account_address"] = ask("\nEnter Ethereum withdrawal address")

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
    config["charon_enabled"] = "true"

    # Charon-specific configuration
    click.echo("\nCharon Distributed Validator Configuration:")
    config["host_charon_enr_private_key"] = ask("Enter your pre-generated Charon ENR private key",
                                                hide_input=True)
    config["charon_name"] = ask("Enter Charon cluster name")
    config["charon_operator_enrs"] = ask("Enter Charon operator ENRs")
    config["charon_fee_recipient_addresses"] = ask("Enter Charon fee recipient address")
    config["charon_withdrawal_addresses"] = ask("Enter Charon withdrawal address")
    config["charon_num_validators"] = click.prompt("Enter number of validators in the cluster",
                                                   type=click.IntRange(min=1))
    config["is_leader"] = yes_no("Is this node the Charon leader?", False)

    # Validator configuration
    click.echo("\nValidator Configuration:")
    config["host_validator_public_key"] = ask("Enter validator public key")
    config["withdrawal_account_address"] = ask("Enter Ethereum withdrawal address")

    # Add validator to the list
    config["validators"] = [{
        "public_key": config["host_validator_public_key"],
        "enabled": True
    }]

    return config


def write_private_file(path, content):
    """Write a file readable only by the current user; host_vars hold passwords and keys."""
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(content)
    os.chmod(path, 0o600)  # in case the file already existed with wider permissions


def main():
    click.echo("Welcome to the Ethereum Staking Node Setup!")
    click.echo("===========================================")

    # Get server information
    server_name = click.prompt("\nEnter a name for this server (e.g. validator1, eth-node2)",
                               value_proc=_server_name)
    server_ip = click.prompt("Enter the server's IP address", value_proc=_ip_address)

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
    config["server_name"] = server_name
    config["IP"] = server_ip
    config["GRAFANA_ADMIN_PASSWORD"] = get_secure_password("\nEnter Grafana admin password")
    config["cadvisor_enabled"] = "true"

    # Get SSH configuration
    ssh_config = get_ssh_config()
    config.update(ssh_config)

    # Telegram notifications (optional)
    if yes_no("\nDo you want to set up Telegram notifications?", False) == "true":
        config["telegram_bot_token"] = ask("Enter Telegram bot token", hide_input=True)
        config["telegram_chat_id"] = ask("Enter Telegram chat ID")
    else:
        config["telegram_bot_token"] = ""
        config["telegram_chat_id"] = ""

    # Ansible loads host_vars/<inventory hostname>.yml automatically, and the inventory
    # below names the host after server_name, so the file must use that name too.
    os.makedirs('host_vars', exist_ok=True)
    host_vars_file = f'host_vars/{server_name}.yml'
    write_private_file(host_vars_file, yaml.safe_dump(config, default_flow_style=False))

    # Create inventory file using server name for readability
    inventory_content = f"""[ethereum_nodes]
{server_name} ansible_host={server_ip} ansible_port={ssh_config['ansible_port']}

[all:vars]
ansible_user={ssh_config['ansible_user']}
ansible_ssh_private_key_file={ssh_config['ansible_ssh_private_key_file']}
ansible_python_interpreter=/usr/bin/python3
"""
    with open('inventory', 'w') as f:
        f.write(inventory_content)

    click.echo("\nConfiguration complete!")
    click.echo("=======================")
    click.echo("\nCreated files:")
    click.echo(f"1. {host_vars_file} - Contains your node configuration")
    click.echo("2. inventory - Contains your server information")
    click.echo("\nNext steps:")

    if deployment_type == 1:
        click.echo("Run the Ansible playbook to set up your Ethereum node:")
        click.echo("   ansible-playbook -i inventory main.yml")
    elif deployment_type == 2:
        click.echo("1. Add your validator keys to the host_vars configuration file")
        click.echo("2. Run the Ansible playbook to set up your validator node:")
        click.echo("   ansible-playbook -i inventory main.yml")
    else:  # deployment_type == 3
        click.echo("1. Set up your Charon cluster:")
        click.echo("   - Follow the Obol documentation to generate your ENR")
        click.echo("   - Update the Charon configuration in your host_vars file")
        click.echo("2. Add your validator keys to the host_vars configuration file")
        click.echo("3. Run the Ansible playbook to set up your distributed validator node:")
        click.echo("   ansible-playbook -i inventory main.yml")


if __name__ == "__main__":
    main()

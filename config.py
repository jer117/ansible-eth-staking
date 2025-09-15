#!/usr/bin/env python3

# MEV Relay Data
mainnet_relay_options = [
    {
        'name': 'Aestus',
        'url': 'https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live'
    },
    {
        'name': 'Agnostic Gnosis',
        'url': 'https://0xa7ab7a996c8584251c8f925da3170bdfd6ebc75d50f5ddc4050a6fdc77f2a3b5fce2cc750d0865e05d7228af97d69561@agnostic-relay.net'
    },
    {
        'name': 'bloXroute Max Profit',
        'url': 'https://0x8b5d2e73e2a3a55c6c87b8b6eb92e0149a125c852751db1422fa951e42a09b82c142c3ea98d0d9930b056a3bc9896b8f@bloxroute.max-profit.blxrbdn.com'
    },
    {
        'name': 'bloXroute Regulated',
        'url': 'https://0xb0b07cd0abef743db4260b0ed50619cf6ad4d82064cb4fbec9d3ec530f7c5e6793d9f286c4e082c0244ffb9f2658fe88@bloxroute.regulated.blxrbdn.com'
    },
    {
        'name': 'Flashbots',
        'url': 'https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net'
    },
    {
        'name': 'Ultra Sound',
        'url': 'https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money'
    }
]

holesky_relay_options = [
    {
        'name': 'Aestus',
        'url': 'https://0xab78bf8c781c58078c3beb5710c57940874dd96aef2835e7742c866b4c7c0406754376c2c8285a36c630346aa5c5f833@holesky.aestus.live'
    },
    {
        'name': 'Ultra Sound',
        'url': 'https://0xb1559beef7b5ba3127485bbbb090362d9f497ba64e177ee2c8e7db74746306efad687f2cf8574e38d70067d40ef136dc@relay-stag.ultrasound.money'
    },
    {
        'name': 'Flashbots',
        'url': 'https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-holesky.flashbots.net'
    },
    {
        'name': 'bloXroute',
        'url': 'https://0x821f2a65afb70e7f2e820a925a9b4c80a159620582c1766b1b09729fec178b11ea22abb3a51f07b288be815a1a2ff516@bloxroute.holesky.blxrbdn.com'
    },
    {
        'name': 'Eden Network',
        'url': 'https://0xb1d229d9c21298a87846c7022ebeef277dfc321fe674fa45312e20b5b6c400bfde9383f801848d7837ed5fc449083a12@relay-holesky.edennetwork.io'
    },
    {
        'name': 'Titan Relay',
        'url': 'https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@holesky.titanrelay.xyz'
    }
]

sepolia_relay_options = [
    {
        'name': 'Flashbots',
        'url': 'https://0x845bd072b7cd566f02faeb0a4033ce9399e42839ced64e8b2adcfc859ed1e8e1a5a293336a49feac6d9a5edb779be53a@boost-relay-sepolia.flashbots.net'
    }
]

hoodi_relay_options = [
    {
        'name': 'Titan Relay',
        'url': 'https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@hoodi.titanrelay.xyz'
    },
    {
        'name': 'Flashbots',
        'url': 'https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-hoodi.flashbots.net'
    },
    {
        'name': 'bloXroute',
        'url': 'https://0x821f2a65afb70e7f2e820a925a9b4c80a159620582c1766b1b09729fec178b11ea22abb3a51f07b288be815a1a2ff516@bloxroute.hoodi.blxrbdn.com'
    },
    {
        'name': 'Aestus',
        'url': 'https://0x98f0ef62f00780cf8eb06701a7d22725b9437d4768bb19b363e882ae87129945ec206ec2dc16933f31d983f8225772b6@hoodi.aestus.live'
    }
]

# Checkpoint-Sync Data
mainnet_sync_urls = [
    ("ETHSTAKER", "https://beaconstate.ethstaker.cc"),
    ("BEACONCHA.IN", "https://sync-mainnet.beaconcha.in"),
    ("ATTESTANT", "https://mainnet-checkpoint-sync.attestant.io"),
    ("SIGMA PRIME", "https://mainnet.checkpoint.sigp.io"),
    ("Lodestar", "https://beaconstate-mainnet.chainsafe.io"),
    ("BeaconState.info", "https://beaconstate.info"),
    ("PietjePuk", "https://checkpointz.pietjepuk.net"),
    ("invistools", "https://sync.invis.tools"),
    ("Nimbus", "http://testing.mainnet.beacon-api.nimbus.team"),
]

holesky_sync_urls = [
    ("BEACONSTATE", "https://holesky.beaconstate.info"),
    ("EF DevOps", "https://checkpoint-sync.holesky.ethpandaops.io"),
    ("Lodestar", "https://beaconstate-holesky.chainsafe.io"),
]

sepolia_sync_urls = [
    ("Beaconstate", "https://sepolia.beaconstate.info"),
    ("Lodestar", "https://beaconstate-sepolia.chainsafe.io"),
    ("EF DevOps", "https://checkpoint-sync.sepolia.ethpandaops.io"),
]

hoodi_sync_urls = [
    ("EF DevOps", "https://checkpoint-sync.hoodi.ethpandaops.io"),
    ("ATTESTANT", "https://hoodi-checkpoint-sync.attestant.io"),
]

def get_relay_urls(network, selected_relays=None):
    """
    Get relay URLs for the specified network.
    If selected_relays is provided, only return those specific relays.
    """
    relay_options = {
        'mainnet': mainnet_relay_options,
        'holesky': holesky_relay_options,
        'sepolia': sepolia_relay_options,
        'hoodi': hoodi_relay_options
    }.get(network.lower(), [])
    
    if not selected_relays:
        return ','.join(relay['url'] for relay in relay_options)
    
    selected_urls = []
    for relay in relay_options:
        if relay['name'] in selected_relays:
            selected_urls.append(relay['url'])
    
    return ','.join(selected_urls)

def get_sync_urls(network):
    """Get checkpoint sync URLs for the specified network."""
    return {
        'mainnet': mainnet_sync_urls,
        'holesky': holesky_sync_urls,
        'sepolia': sepolia_sync_urls,
        'hoodi': hoodi_sync_urls
    }.get(network.lower(), [])

import os
import yaml
from typing import Dict, List, Optional

def load_yaml_config(file_path: str) -> dict:
    """Load configuration from a YAML file."""
    try:
        with open(file_path, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        return {}

def get_charon_config(config_file: Optional[str] = None) -> Dict:
    """
    Get Charon configuration settings.
    
    Args:
        config_file: Path to YAML configuration file. If not provided,
                    will look for environment variables.
    
    Returns:
        Dictionary containing Charon configuration
    """
    config = {}
    
    if config_file:
        yaml_config = load_yaml_config(config_file)
        config = {
            'private_key': yaml_config.get('host_charon_enr_private_key'),
            'name': yaml_config.get('charon_name'),
            'operator_enrs': yaml_config.get('charon_operator_enrs'),
            'fee_recipient_addresses': yaml_config.get('charon_fee_recipient_addresses'),
            'withdrawal_addresses': yaml_config.get('charon_withdrawal_addresses'),
            'num_validators': yaml_config.get('charon_num_validators'),
            'is_leader': yaml_config.get('is_leader', False),
            'enabled': yaml_config.get('charon_enabled', False)
        }
    else:
        # Fallback to environment variables
        config = {
            'private_key': os.getenv('CHARON_PRIVATE_KEY'),
            'name': os.getenv('CHARON_NAME'),
            'operator_enrs': os.getenv('CHARON_OPERATOR_ENRS'),
            'fee_recipient_addresses': os.getenv('CHARON_FEE_RECIPIENT_ADDRESSES'),
            'withdrawal_addresses': os.getenv('CHARON_WITHDRAWAL_ADDRESSES'),
            'num_validators': int(os.getenv('CHARON_NUM_VALIDATORS', '0')),
            'is_leader': os.getenv('CHARON_IS_LEADER', 'false').lower() == 'true',
            'enabled': os.getenv('CHARON_ENABLED', 'false').lower() == 'true'
        }
    
    return {k: v for k, v in config.items() if v is not None}

def get_validator_config(config_file: Optional[str] = None) -> Dict:
    """
    Get validator configuration settings.
    
    Args:
        config_file: Path to YAML configuration file. If not provided,
                    will look for environment variables.
    
    Returns:
        Dictionary containing validator configuration
    """
    config = {}
    
    if config_file:
        yaml_config = load_yaml_config(config_file)
        validators = yaml_config.get('validators', [])
        config = {
            'public_keys': [v['public_key'] for v in validators if v.get('enabled', True)],
            'withdrawal_address': yaml_config.get('withdrawal_account_address'),
            'client': yaml_config.get('validator_client', 'lighthouse')
        }
    else:
        # Fallback to environment variables
        public_keys = os.getenv('VALIDATOR_PUBLIC_KEYS', '').split(',')
        config = {
            'public_keys': [key.strip() for key in public_keys if key.strip()],
            'withdrawal_address': os.getenv('VALIDATOR_WITHDRAWAL_ADDRESS'),
            'client': os.getenv('VALIDATOR_CLIENT', 'lighthouse')
        }
    
    return {k: v for k, v in config.items() if v is not None}

def create_host_config(
    ip_address: str,
    charon_private_key: str,
    charon_name: str,
    charon_operator_enrs: str,
    charon_fee_recipient: str,
    charon_withdrawal: str,
    charon_num_validators: int,
    validator_public_key: str,
    is_leader: bool = False,
    charon_enabled: bool = True,
    validator_client: str = "lodestar",
    cadvisor_enabled: bool = True
) -> Dict:
    """
    Create a new host configuration dictionary.
    
    Args:
        ip_address: The IP address of the host
        charon_private_key: The Charon ENR private key
        charon_name: The name for the Charon node
        charon_operator_enrs: The operator ENRs string
        charon_fee_recipient: The fee recipient address
        charon_withdrawal: The withdrawal address
        charon_num_validators: Number of validators
        validator_public_key: The validator's public key
        is_leader: Whether this node is a leader (default: False)
        charon_enabled: Whether Charon is enabled (default: True)
        validator_client: The validator client to use (default: "lodestar")
        cadvisor_enabled: Whether cAdvisor is enabled (default: True)
    
    Returns:
        Dictionary containing the host configuration
    """
    return {
        # Charon Configuration
        'charon_enabled': charon_enabled,
        'is_leader': is_leader,
        'host_charon_enr_private_key': charon_private_key,
        'charon_name': charon_name,
        'charon_operator_enrs': charon_operator_enrs,
        'charon_fee_recipient_addresses': charon_fee_recipient,
        'charon_withdrawal_addresses': charon_withdrawal,
        'charon_num_validators': charon_num_validators,
        'host_validator_public_key': validator_public_key,
        
        # Validator Configuration
        'withdrawal_account_address': charon_fee_recipient,
        'validator_client': validator_client,
        
        # Monitoring Configuration
        'cadvisor_enabled': cadvisor_enabled,
        
        # Validator Keys
        'validators': [
            {
                'public_key': validator_public_key,
                'enabled': True
            }
        ]
    }

def save_host_config(ip_address: str, config: Dict, base_path: str = "host_vars") -> None:
    """
    Save a host configuration to a YAML file.
    
    Args:
        ip_address: The IP address of the host
        config: The configuration dictionary to save
        base_path: The base path for host_vars (default: "host_vars")
    """
    os.makedirs(base_path, exist_ok=True)
    file_path = os.path.join(base_path, f"{ip_address}.yml")
    
    with open(file_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)

def update_host_config(
    ip_address: str,
    updates: Dict,
    base_path: str = "host_vars"
) -> None:
    """
    Update an existing host configuration.
    
    Args:
        ip_address: The IP address of the host
        updates: Dictionary containing the fields to update
        base_path: The base path for host_vars (default: "host_vars")
    """
    file_path = os.path.join(base_path, f"{ip_address}.yml")
    current_config = load_yaml_config(file_path)
    
    # Update the configuration
    current_config.update(updates)
    
    # Save back to file
    save_host_config(ip_address, current_config, base_path)

def interactive_host_setup():
    """Interactive setup for host configuration."""
    print("\n=== Ethereum Node and Validator Setup ===\n")
    
    # Get host type
    print("What type of node is this?")
    print("1. Ethereum Node (No validator)")
    print("2. Validator Node with Charon")
    host_type = input("Enter choice (1/2): ").strip()
    
    # Common configuration
    ip_address = input("\nEnter the IP address for this host: ").strip()
    
    if host_type == "1":
        # Ethereum Node Configuration
        config = {
            'charon_enabled': False,
            'cadvisor_enabled': True,
            'validator_client': None,
            'validators': []
        }
        save_host_config(ip_address, config)
        print(f"\nCreated Ethereum node configuration for {ip_address}")
        
    elif host_type == "2":
        # Validator Node Configuration
        print("\n=== Charon Configuration ===")
        
        # Charon specific configuration
        charon_private_key = input("Enter your pre-generated Charon private key: ").strip()
        charon_name = input("Enter Charon node name: ").strip()
        charon_operator_enrs = input("Enter Charon operator ENRs: ").strip()
        charon_fee_recipient = input("Enter Charon fee recipient address: ").strip()
        charon_withdrawal = input("Enter Charon withdrawal address: ").strip()
        num_validators = int(input("Enter number of validators: ").strip())
        is_leader = input("Is this a leader node? (yes/no): ").lower().strip() == 'yes'
        
        print("\n=== Validator Configuration ===")
        validator_public_key = input("Enter validator public key: ").strip()
        eth_withdrawal_address = input("Enter Ethereum withdrawal address: ").strip()
        validator_client = input("Enter validator client (lighthouse/lodestar): ").strip().lower()
        
        # Create and save configuration
        config = {
            # Charon Configuration
            'charon_enabled': True,
            'is_leader': is_leader,
            'host_charon_enr_private_key': charon_private_key,
            'charon_name': charon_name,
            'charon_operator_enrs': charon_operator_enrs,
            'charon_fee_recipient_addresses': charon_fee_recipient,
            'charon_withdrawal_addresses': charon_withdrawal,
            'charon_num_validators': num_validators,
            'host_validator_public_key': validator_public_key,
            
            # Validator Configuration
            'withdrawal_account_address': eth_withdrawal_address,
            'validator_client': validator_client,
            
            # Monitoring Configuration
            'cadvisor_enabled': True,
            
            # Validator Keys
            'validators': [
                {
                    'public_key': validator_public_key,
                    'enabled': True
                }
            ]
        }
        
        save_host_config(ip_address, config)
        print(f"\nCreated validator node configuration for {ip_address}")
    
    else:
        print("Invalid choice. Please run again and select 1 or 2.")

if __name__ == "__main__":
    interactive_host_setup()

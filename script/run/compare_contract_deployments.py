#!/usr/bin/env python3

import json
import os
import glob
from pathlib import Path

def load_json_file(filepath):
    """Load JSON file with error handling"""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading {filepath}: {e}")
        return None

def compare_contracts(main_contracts, network_contracts, network_name):
    """Compare contracts between main and network-specific files"""
    matches = {}
    mismatches = {}
    missing_in_network = {}
    extra_in_network = {}
    
    # Check contracts in main file
    for contract_name, main_address in main_contracts.items():
        if contract_name in network_contracts:
            network_address = network_contracts[contract_name]
            if main_address == network_address:
                matches[contract_name] = main_address
            else:
                mismatches[contract_name] = {
                    'main': main_address,
                    'network': network_address
                }
        else:
            missing_in_network[contract_name] = main_address
    
    # Check for extra contracts in network file
    for contract_name, network_address in network_contracts.items():
        if contract_name not in main_contracts:
            extra_in_network[contract_name] = network_address
    
    return {
        'matches': matches,
        'mismatches': mismatches,
        'missing_in_network': missing_in_network,
        'extra_in_network': extra_in_network
    }

def main():
    # Set up paths relative to script location
    script_dir = Path(__file__).parent
    base_dir = script_dir.parent.parent  # Go up to project root
    output_dir = base_dir / "script" / "output" / "prod"
    
    main_file = output_dir / "latest.json"
    
    print("🔍 Contract Deployment Comparison Report")
    print("=" * 50)
    
    # Load main file
    main_data = load_json_file(main_file)
    if not main_data:
        print("❌ Could not load main latest.json file")
        return
    
    print(f"📁 Main file loaded: {main_file}")
    print(f"🌐 Networks in main file: {len(main_data.get('networks', {}))}")
    print()
    
    # Find all network-specific files
    network_files = glob.glob(str(output_dir / "*" / "*-latest.json"))
    network_files.sort()
    
    print(f"📋 Found {len(network_files)} network-specific files:")
    for nf in network_files:
        print(f"  • {Path(nf).name}")
    print()
    
    # Process each network
    total_networks = 0
    perfect_matches = 0
    
    for network_file in network_files:
        network_path = Path(network_file)
        chain_id = network_path.parent.name
        network_name = network_path.stem.replace('-latest', '')
        
        total_networks += 1
        
        print(f"🔗 Network: {network_name} (Chain ID: {chain_id})")
        print("-" * 40)
        
        # Load network file
        network_data = load_json_file(network_file)
        if not network_data:
            print("❌ Could not load network file")
            print()
            continue
        
        # Get contracts from main file for this network
        main_network_data = main_data.get('networks', {}).get(network_name, {})
        main_contracts = main_network_data.get('contracts', {})
        
        # Get contracts from network file (network files are directly contract objects)
        network_contracts = network_data
        
        if not main_contracts:
            print(f"⚠️  No contracts found for {network_name} in main file")
            print()
            continue
            
        if not network_contracts:
            print(f"⚠️  No contracts found in {network_name} network file")
            print()
            continue
        
        # Compare contracts
        comparison = compare_contracts(main_contracts, network_contracts, network_name)
        
        # Print results
        print(f"📊 Contract Summary:")
        print(f"  ✅ Matches: {len(comparison['matches'])}")
        print(f"  ❌ Mismatches: {len(comparison['mismatches'])}")
        print(f"  ⚠️  Missing in network: {len(comparison['missing_in_network'])}")
        print(f"  ➕ Extra in network: {len(comparison['extra_in_network'])}")
        
        # Check if perfect match
        is_perfect = (len(comparison['mismatches']) == 0 and 
                     len(comparison['missing_in_network']) == 0 and 
                     len(comparison['extra_in_network']) == 0)
        
        if is_perfect:
            perfect_matches += 1
            print("🎯 PERFECT MATCH! All contracts are identical.")
        else:
            # Show mismatches
            if comparison['mismatches']:
                print("\n❌ Address Mismatches:")
                for contract, addresses in comparison['mismatches'].items():
                    print(f"  • {contract}:")
                    print(f"    Main:    {addresses['main']}")
                    print(f"    Network: {addresses['network']}")
            
            # Show missing contracts
            if comparison['missing_in_network']:
                print(f"\n⚠️  Missing in {network_name} file:")
                for contract, address in comparison['missing_in_network'].items():
                    print(f"  • {contract}: {address}")
            
            # Show extra contracts
            if comparison['extra_in_network']:
                print(f"\n➕ Extra in {network_name} file:")
                for contract, address in comparison['extra_in_network'].items():
                    print(f"  • {contract}: {address}")
        
        print()
    
    # Final summary
    print("📈 FINAL SUMMARY")
    print("=" * 50)
    print(f"🌐 Total networks analyzed: {total_networks}")
    print(f"🎯 Perfect matches: {perfect_matches}")
    print(f"⚠️  Networks with discrepancies: {total_networks - perfect_matches}")
    
    if perfect_matches == total_networks:
        print("🎉 ALL NETWORKS HAVE PERFECT CONTRACT MATCHES!")
    else:
        print(f"⚠️  {total_networks - perfect_matches} network(s) have discrepancies that need attention.")

if __name__ == "__main__":
    main()
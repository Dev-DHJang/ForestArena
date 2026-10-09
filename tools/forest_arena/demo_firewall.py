#!/usr/bin/env python3
"""Print narrow PF rules for review; do not change the host firewall."""
import ipaddress
import re
import sys
if len(sys.argv) != 4: raise SystemExit('usage: demo_firewall.py interface private-ip cidr')
interface, address, cidr = sys.argv[1:]
if not re.fullmatch(r'en[0-9]+', interface): raise SystemExit('invalid macOS interface')
ip = ipaddress.IPv4Address(address)
network = ipaddress.IPv4Network(cidr, strict=True)
if not ip.is_private or ip.is_loopback or ip not in network or network.prefixlen < 16:
    raise SystemExit('a connected private LAN address and narrow CIDR are required')
print(f'pass in quick on lo0 inet proto tcp from {{ 127.0.0.0/8, {ip} }} to {{ 127.0.0.1, {ip} }} port {{ 3001, 7778 }} keep state')
print(f'pass in quick on {interface} inet proto tcp from {network} to {ip} port {{ 3001, 7778 }} keep state')
print(f'block in quick inet proto tcp from any to {ip} port {{ 3001, 7778 }}')

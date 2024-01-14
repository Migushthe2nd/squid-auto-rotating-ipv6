# Squid Auto Rotating IPV6 Proxy

## Docker-compose example

```yml
version: "3.9"

services:
  squid-auto-rotating-ipv6:
    build: .
    network_mode: "host"
    volumes:
      - ./extend-config.example.conf:/etc/squid/extend-config.conf
    environment:
      - ADDRESS_GENERATION_INTERVAL_SECONDS=60 #default
      - ADDRESS_COUNT=100 #default
      - IPV6_SUBNET="2001:db8:0:1::/64"
```
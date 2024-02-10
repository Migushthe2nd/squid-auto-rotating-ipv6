#!/bin/bash

# Generate random IPv6 addresse based on subnet
# First calculate the number of bits required
  #Then convert the subnet address to binary, trim to 128-<bits required> bits as PREFIX_BINARY
  #Generate <bits required>  random binary as GENERATED_BINARY
  #Concat PREFIX_BINARY and GENERATED_BINARY
  #Split on every 16 bits,
  #Convert each 16 bits to hexadecimal, concat with colon
# DONT use ipv6calc, it is not available in alpine
generate_random_ipv6() {
    local subnet=$1
    local subnet_size=$(echo $subnet | awk -F/ '{print $2}')
    local subnet_prefix=$(echo $subnet | awk -F/ '{print $1}')
    # write out the address in full
    local subnet_prefix_padded=$(ipv6calc --in ipv6addr --out ifinet6 $subnet_prefix)
    read -r subnet_prefix_colonless _size <<< "$subnet_prefix_padded"
    #  to uppercase
    local subnet_prefix_colonless_uppercase=$(echo $subnet_prefix_colonless | tr '[:lower:]' '[:upper:]')
    #    convert to binary
    local prefix_binary=$(echo "obase=2; ibase=16; $subnet_prefix_colonless_uppercase" | bc)
    local prefix_trimmed_binary=$(echo $prefix_binary | sed -r "s/.{$subnet_size}$//")

    local bits_required=$((128-$subnet_size))
    local generated_binary=""
    for ((i=1; i<=bits_required; i++)); do
        generated_binary+="$(($RANDOM%2))"
    done
    local ipv6_binary=$prefix_trimmed_binary$generated_binary
    #    convert binary to hex
    local ipv6_hex=$(echo "obase=16; ibase=2; $ipv6_binary" | bc)
    #    pad hex with zeros, split on every 4 characters
    local ipv6_padded=$(printf "%032s" $ipv6_hex | tr ' ' '0')
    local ipv6=$(echo $ipv6_padded | sed -E 's/(.{4})/\1:/g')
    ipv6=${ipv6%:}
    echo $ipv6
}

echo "include /etc/squid/ip-list.conf" >> /etc/squid/squid.conf
if [ -f /etc/squid/extend-config.conf ]; then
    echo "include /etc/squid/extend-config.conf" >> /etc/squid/squid.conf
fi

generate_addresses() {
    touch /etc/squid/ip-list.conf
    truncate -s 0 /etc/squid/ip-list.conf

    for ((i=1; i<=$ADDRESS_COUNT; i++)); do
        echo "acl random$i random 1/$(($ADDRESS_COUNT+1-$i))" >> /etc/squid/ip-list.conf
    done

    for ((i=$ADDRESS_COUNT; i>=1; i--)); do
        random_ipv6=$(generate_random_ipv6 $IPV6_SUBNET)
        echo "tcp_outgoing_address $random_ipv6 random$i" >> /etc/squid/ip-list.conf
    done
}

schedule_generate_addresses() {
    echo "Scheduling address generation every $ADDRESS_GENERATION_INTERVAL_SECONDS seconds"
    generate_addresses
    while true; do
        sleep $ADDRESS_GENERATION_INTERVAL_SECONDS
        generate_addresses
        if [ "$(service squid status | grep -c 'is running')" -gt 0 ]; then
            echo "Reloading squid config"
            squid -k reconfigure
        fi
    done
}

# Set defaults
if [ -z "$ADDRESS_COUNT" ]; then
    ADDRESS_COUNT=10
fi

if [ -z "$ADDRESS_GENERATION_INTERVAL_SECONDS" ]; then
    ADDRESS_GENERATION_INTERVAL_SECONDS=300
fi

if [ -z "$IPV6_SUBNET" ]; then
    echo "IPV6_SUBNET is not set"
    exit 1
fi

# Schedule generation in background
schedule_generate_addresses &
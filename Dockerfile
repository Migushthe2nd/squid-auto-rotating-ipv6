FROM debian:trixie-slim

# Install Squid
RUN apt-get update && apt-get install -y squid bc ipv6calc

# Copy the shell script to generate Squid config
COPY generate-squid-config.sh /generate-squid-config.sh
RUN chmod +x /generate-squid-config.sh

# Set environment variables
ENV BC_LINE_LENGTH=0

# Run the shell script to generate Squid config and start Squid
CMD ["/bin/bash", "-c", "/generate-squid-config.sh && squid -N -d 1"]

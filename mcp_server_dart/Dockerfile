# Use the official Dart image
FROM dart:stable AS build

# Set working directory
WORKDIR /app

# Copy current directory contents
COPY . .

# Get dependencies
RUN dart pub get

# Create a startup script
RUN echo '#!/bin/bash\nexec dart bin/main.dart "$@"' > /app/start.sh && chmod +x /app/start.sh

# Expose the default MCP port
EXPOSE 8181

# Start the MCP server with proper arguments
ENTRYPOINT ["/app/start.sh"]
CMD ["--images", "--resources", "--log-level=info"] 
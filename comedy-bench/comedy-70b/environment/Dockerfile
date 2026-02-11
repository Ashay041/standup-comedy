FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
# Pin httpx<0.28 because newer httpx removed 'proxies' param that openai uses
RUN pip install --no-cache-dir \
    "httpx>=0.25.0,<0.28.0" \
    pyautogen==0.3.2 \
    openai==1.54.0

# Set working directory
WORKDIR /app

# Copy the comedy script
COPY comedy_exchange.py /app/

# Copy environment file with API keys
COPY .env.docker /app/.env

# Create output directory
RUN mkdir -p /output /logs/verifier

# Default command (overridden by solve.sh)
CMD ["python", "comedy_exchange.py"]

FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install dbt-starrocks
RUN pip install --no-cache-dir \
    dbt-core==1.8.8 \
    dbt-starrocks==1.8.0

# Create working directory
WORKDIR /dbt

# Set entrypoint
ENTRYPOINT ["dbt"]

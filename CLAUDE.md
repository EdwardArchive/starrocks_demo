# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based demo environment for MySQL to StarRocks CDC (Change Data Capture) using scheduled Tasks. The project demonstrates data synchronization from MySQL to StarRocks using External Catalogs and Primary Key tables.

## Common Commands

### Starting the Environment

```bash
# BE mode (local disk storage, traditional architecture)
docker compose --profile be up -d

# CN mode (S3/MinIO storage, compute-storage separation)
docker compose --profile cn up -d

# BE + Flink CDC mode (real-time binlog-based sync)
docker compose --profile be --profile flink up -d --build

# CN + Flink CDC mode
docker compose --profile cn --profile flink up -d --build

# BE + RisingWave CDC mode (streaming database CDC)
docker compose --profile be --profile risingwave up -d

# CN + RisingWave CDC mode
docker compose --profile cn --profile risingwave up -d
```

### Checking Service Status

```bash
docker compose --profile be ps   # or --profile cn
docker logs -f starrocks-fe
```

### Connecting to Databases

```bash
# MySQL
mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#'

# StarRocks
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'
```

### Flink CDC Commands (when using flink profile)

```bash
# Start CDC pipeline
docker exec flink-jobmanager flink-cdc.sh /opt/flink-cdc/pipelines/mysql-to-starrocks.yaml

# List running jobs
docker exec flink-jobmanager flink list

# Cancel a job
docker exec flink-jobmanager flink cancel <JOB_ID>
```

### RisingWave CDC Commands (when using risingwave profile)

```bash
# Connect to RisingWave (PostgreSQL protocol)
psql -h 127.0.0.1 -p 4566 -U root -d dev

# Or via Docker
docker exec -it risingwave psql -h localhost -p 4566 -U root -d dev

# Run setup pipeline script
docker exec -i risingwave psql -h localhost -p 4566 -U root -d dev < cdc/risingwave/setup-pipeline.sql

# Check sources, tables, sinks
# SHOW SOURCES;
# SHOW TABLES;
# SHOW SINKS;

# Dashboard URL: http://localhost:5691
```

### Rill Commands (when using rill profile)

```bash
# BE mode + Rill
docker compose --profile be --profile rill up -d

# CN mode + Rill
docker compose --profile cn --profile rill up -d

# Access Rill Dashboard
# http://localhost:9010

# Check Rill logs
docker logs -f rill
```

### Monitoring Commands (when using monitoring profile)

```bash
# BE mode + Monitoring
docker compose --profile be --profile monitoring up -d

# CN mode + Monitoring
docker compose --profile cn --profile monitoring up -d

# Access monitoring services
# Grafana: http://localhost:3000 (admin / starrocks_demo_pw1#)
# Prometheus: http://localhost:9090
# AlertManager: http://localhost:9093

# Check monitoring logs
docker logs -f prometheus
docker logs -f grafana
docker logs -f loki
```

### Cleanup

```bash
# Stop services
docker compose --profile be down

# Stop and remove volumes (full reset)
docker compose --profile be down -v
```

## Architecture

### Two Deployment Modes

- **BE (Backend) Mode**: Traditional shared-nothing architecture with local disk storage. Best for low-latency OLAP workloads.
- **CN (Compute Node) Mode**: Shared-data architecture using MinIO (S3-compatible) storage. Enables independent compute/storage scaling.

### Data Flow

1. MySQL source database (`demo_db.products`) with binlog enabled
2. StarRocks JDBC External Catalog (`mysql_catalog`) connects to MySQL
3. StarRocks Primary Key table (`analytics_db.products_sync`) stores synchronized data
4. Scheduled Task runs periodic INSERT...SELECT for incremental sync

### Key Components

| Service | Port | Purpose |
|---------|------|---------|
| MySQL | 3306 | Source database |
| StarRocks FE | 9030 (MySQL), 8030 (Web UI) | Query engine |
| StarRocks BE/CN | 9050 | Storage/Compute |
| MinIO (CN only) | 9000, 9001 | Object storage |
| Flink (flink profile) | 8082 (Web UI) | CDC stream processing |
| RisingWave (risingwave profile) | 4566 (SQL), 5691 (Dashboard) | Streaming CDC database |
| Rill (rill profile) | 9010 | BI Dashboard |
| Prometheus (monitoring profile) | 9090 | Metrics collection |
| Grafana (monitoring profile) | 3000 | Visualization dashboard |
| Loki (monitoring profile) | 3100 | Log aggregation |
| AlertManager (monitoring profile) | 9093 | Alert management |

## Key Files

- `docker-compose.yml` - Service definitions with profile-based deployment
- `scripts/mysql-init.sql` - MySQL schema and sample data (1005 products)
- `scripts/mysql-orders-init.sql` - MySQL orders table schema and sample data (100 orders)
- `scripts/starrocks-be-init.sql` - BE mode initialization SQL
- `scripts/starrocks-cn-init.sql` - CN mode initialization SQL
- `scripts/starrocks-risingwave-init.sql` - RisingWave mode StarRocks initialization SQL
- `config/` - Configuration files for MySQL, FE, BE, and CN
- `cdc/flink/Dockerfile` - Custom Flink image with CDC connectors
- `cdc/flink/pipelines/mysql-to-starrocks.yaml` - Flink CDC pipeline configuration
- `cdc/risingwave/setup-pipeline.sql` - RisingWave CDC pipeline setup SQL
- `docs/CDC_Flink.md` - Flink CDC user guide (Korean)
- `docs/CDC_RisingWave.md` - RisingWave CDC user guide (Korean)
- `docs/Syncdata_MySQL.md` - Task scheduling user guide (Korean)
- `bi/rill-project/` - Rill BI dashboard project
- `scripts/starrocks-rill-init.sql` - Rill mode StarRocks initialization
- `docs/Dashboard_Rill.md` - Rill dashboard guide (Korean)
- `config/prometheus/` - Prometheus configuration files
- `config/loki/` - Loki configuration files
- `config/promtail/` - Promtail log collection configuration
- `config/alertmanager/` - AlertManager alert routing configuration
- `config/grafana/dashboards/` - Grafana dashboard JSON files
- `docs/Monitoring.md` - Monitoring system user guide (Korean)
- `scripts/starrocks-rbac-init.sql` - RBAC roles and users initialization SQL
- `scripts/starrocks-rbac-verify.sh` - RBAC permission verification demo script
- `docs/RBAC.md` - RBAC demo user guide (Korean)

## CDC Implementation Details

### Option 1: Task Scheduling (default)
- External Catalog provides federated query access to MySQL
- Primary Key table enables UPSERT behavior for CDC
- Task runs every 5 minutes, syncing records changed in last 10 minutes
- Uses `last_updated` timestamp column for incremental detection

### Option 2: Flink CDC (flink profile)
- Real-time binlog-based synchronization (millisecond latency)
- Automatic schema creation in StarRocks
- Schema change propagation (DDL sync with CDC 3.0+)
- Requires Flink cluster (JobManager + TaskManager)

### Option 3: RisingWave CDC (risingwave profile)
- Real-time binlog-based synchronization (millisecond latency)
- PostgreSQL-compatible SQL interface for pipeline configuration
- Lightweight standalone deployment (single node)
- Built-in web dashboard for monitoring
- Uses orders table for demo (products table used by Task/Flink)

### Option 4: Rill BI Dashboard (rill profile)
- StarRocks data visualization with YAML-based dashboards
- Network-isolated architecture (Rill can only access StarRocks)
- NYC Yellow Taxi sample data included
- Nginx reverse proxy for external access

## Credentials

- MySQL: `root` / `starrocks_demo_pw1#`
- StarRocks: `root` / `starrocks_demo_pw1#`
- StarRocks RBAC demo users (10 users): `demo_pw1#` (diana_admin, frank_secops, grace_cto, harry_lead, charlie_engineer, ivan_junior, jenny_lead, alice_analyst, bob_senior, kate_intern)
- MinIO: `admin` / `starrocks_demo_pw1#_minio`

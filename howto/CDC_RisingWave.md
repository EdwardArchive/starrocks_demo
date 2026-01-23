# RisingWave를 사용한 MySQL → StarRocks 실시간 동기화

## 개요

이 가이드는 RisingWave를 사용하여 MySQL 데이터를 StarRocks로 실시간 동기화하는 방법을 설명합니다.

### RisingWave란?

RisingWave는 PostgreSQL 호환 스트리밍 데이터베이스로, 실시간 CDC 파이프라인을 SQL로 간단하게 구성할 수 있습니다.

### CDC 방식 비교

| 항목 | Task 스케줄링 | Flink CDC | RisingWave |
|-----|-------------|-----------|------------|
| 동기화 방식 | 폴링 (5분 주기) | 실시간 binlog | 실시간 binlog |
| 지연 시간 | 최대 5분 | 밀리초 단위 | 밀리초 단위 |
| 스키마 변경 | 수동 처리 | 자동 전파 (3.0+) | 수동 처리 |
| 설정 방식 | StarRocks SQL | YAML/SQL | PostgreSQL SQL |
| 리소스 | StarRocks만 | Flink 클러스터 | RisingWave 단일 노드 |
| 학습 곡선 | 낮음 | 중간 | 낮음 |
| 모니터링 | StarRocks UI | Flink Web UI | RisingWave Dashboard |

### RisingWave의 장점

- **PostgreSQL 호환**: 익숙한 SQL 문법으로 CDC 파이프라인 구성
- **경량 배포**: 단일 노드로 간편하게 시작 (standalone 모드)
- **내장 상태 관리**: 별도의 상태 저장소 불필요
- **Web Dashboard**: 직관적인 파이프라인 모니터링

---

## Step 1: 환경 시작

### BE 모드 + RisingWave

```bash
docker compose --profile be --profile risingwave up -d
```

### CN 모드 + RisingWave

```bash
docker compose --profile cn --profile risingwave up -d
```

### 서비스 상태 확인

```bash
docker compose --profile be --profile risingwave ps
```

모든 서비스가 healthy 상태가 될 때까지 대기합니다 (약 1-2분).

### 접속 정보

| 서비스 | 포트 | 접속 방법 |
|--------|------|----------|
| RisingWave SQL | 4566 | `psql -h 127.0.0.1 -p 4566 -U root -d dev` |
| RisingWave Dashboard | 5691 | http://localhost:5691 |
| MySQL | 3306 | `mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#'` |
| StarRocks | 9030 | `mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'` |

---

## Step 2: StarRocks 테이블 생성

RisingWave에서 데이터를 받을 StarRocks 테이블을 먼저 생성합니다.

### StarRocks 접속

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'
```

### 데이터베이스 및 테이블 생성

```sql
-- 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- orders 동기화 테이블 생성 (Primary Key 테이블)
CREATE TABLE IF NOT EXISTS orders_sync (
    order_id INT,
    customer_name VARCHAR(100),
    product_id INT,
    quantity INT,
    total_amount DECIMAL(12, 2),
    order_status VARCHAR(20),
    shipping_address VARCHAR(255),
    order_date DATETIME,
    last_updated DATETIME
)
PRIMARY KEY (order_id)
DISTRIBUTED BY HASH(order_id) BUCKETS 3
PROPERTIES (
    "replication_num" = "1",
    "enable_persistent_index" = "true"
);

-- 테이블 확인
DESCRIBE analytics_db.orders_sync;
```

또는 스크립트 파일 사용:

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' < scripts/starrocks-risingwave-init.sql
```

---

## Step 3: RisingWave CDC 파이프라인 설정

### RisingWave 접속

```bash
# psql 클라이언트 사용 (Docker 내부)
docker exec -it risingwave psql -h localhost -p 4566 -U root -d dev
```

또는 호스트에서 직접:

```bash
psql -h 127.0.0.1 -p 4566 -U root -d dev
```

### 1. MySQL CDC 소스 생성

MySQL binlog를 읽어서 CDC 이벤트를 캡처하는 소스를 생성합니다.

```sql
CREATE SOURCE IF NOT EXISTS mysql_cdc_source WITH (
    connector = 'mysql-cdc',
    hostname = 'mysql',
    port = '3306',
    username = 'root',
    password = 'starrocks_demo_pw1#',
    database.name = 'demo_db',
    server.id = '5501'
);
```

### 2. CDC 테이블 생성

MySQL의 orders 테이블을 RisingWave 테이블로 매핑합니다.

```sql
CREATE TABLE IF NOT EXISTS orders_cdc (
    *,
    PRIMARY KEY (order_id)
) FROM mysql_cdc_source TABLE 'demo_db.orders';
```

### 3. StarRocks Sink 생성

RisingWave에서 캡처한 CDC 데이터를 StarRocks로 실시간 전송합니다.

```sql
CREATE SINK IF NOT EXISTS orders_starrocks_sink AS
SELECT
    order_id,
    customer_name,
    product_id,
    quantity,
    total_amount,
    order_status,
    shipping_address,
    order_date::TIMESTAMP AS order_date,
    last_updated::TIMESTAMP AS last_updated
FROM orders_cdc
WITH (
    connector = 'starrocks',
    type = 'upsert',
    starrocks.host = 'starrocks-fe',
    starrocks.mysqlport = '9030',
    starrocks.httpport = '8030',
    starrocks.user = 'root',
    starrocks.password = 'starrocks_demo_pw1#',
    starrocks.database = 'analytics_db',
    starrocks.table = 'orders_sync',
    primary_key = 'order_id'
);
```

또는 스크립트 파일 사용:

```bash
docker exec -i risingwave psql -h localhost -p 4566 -U root -d dev < risingwave-cdc/setup-pipeline.sql
```

### 파이프라인 확인

```sql
-- 소스 확인
SHOW SOURCES;

-- 테이블 확인
SHOW TABLES;

-- Sink 확인
SHOW SINKS;
```

---

## Step 4: 실시간 동기화 테스트

### MySQL 데이터 확인

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#' demo_db
```

```sql
-- 초기 데이터 확인
SELECT COUNT(*) FROM orders;
SELECT * FROM orders LIMIT 5;
```

### StarRocks 동기화 확인

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'
```

```sql
-- 동기화된 데이터 확인
SELECT COUNT(*) FROM analytics_db.orders_sync;
SELECT * FROM analytics_db.orders_sync LIMIT 5;
```

### INSERT 테스트

```sql
-- MySQL에서 신규 주문 추가
INSERT INTO demo_db.orders (customer_name, product_id, quantity, total_amount, order_status, shipping_address)
VALUES ('테스트고객', 1, 2, 2400000.00, 'pending', '서울시 테스트구 테스트동 123');
```

```sql
-- StarRocks에서 확인 (몇 초 후)
SELECT * FROM analytics_db.orders_sync WHERE customer_name = '테스트고객';
```

### UPDATE 테스트

```sql
-- MySQL에서 주문 상태 변경
UPDATE demo_db.orders SET order_status = 'shipped' WHERE customer_name = '테스트고객';
```

```sql
-- StarRocks에서 확인
SELECT order_id, customer_name, order_status FROM analytics_db.orders_sync WHERE customer_name = '테스트고객';
```

### DELETE 테스트

```sql
-- MySQL에서 주문 삭제
DELETE FROM demo_db.orders WHERE customer_name = '테스트고객';
```

```sql
-- StarRocks에서 삭제 확인 (Primary Key 테이블이므로 실제 삭제됨)
SELECT * FROM analytics_db.orders_sync WHERE customer_name = '테스트고객';
```

---

## Step 5: 모니터링

### RisingWave Dashboard

브라우저에서 http://localhost:5691 접속

- **Sources**: CDC 소스 상태 확인
- **Tables**: CDC 테이블 및 데이터 확인
- **Sinks**: StarRocks 싱크 상태 확인
- **Streaming Jobs**: 실행 중인 스트리밍 작업 확인

### RisingWave 내부 데이터 확인

```sql
-- RisingWave에서 CDC 데이터 직접 조회
SELECT * FROM orders_cdc ORDER BY order_id DESC LIMIT 10;

-- 주문 상태별 집계
SELECT order_status, COUNT(*) as cnt, SUM(total_amount) as total
FROM orders_cdc
GROUP BY order_status;
```

---

## Step 6: 파이프라인 관리

### Sink 중지/삭제

```sql
-- Sink 삭제 (CDC 파이프라인 중지)
DROP SINK orders_starrocks_sink;
```

### 테이블 삭제

```sql
-- CDC 테이블 삭제
DROP TABLE orders_cdc;
```

### 소스 삭제

```sql
-- CDC 소스 삭제
DROP SOURCE mysql_cdc_source;
```

### 로그 확인

```bash
docker logs -f risingwave
```

---

## 트러블슈팅

### RisingWave가 시작되지 않는 경우

```bash
# 컨테이너 상태 확인
docker compose --profile be --profile risingwave ps

# 로그 확인
docker logs risingwave
```

### MySQL CDC 연결 오류

```bash
# MySQL binlog 설정 확인
docker exec mysql mysql -u root -p'starrocks_demo_pw1#' -e "SHOW VARIABLES LIKE 'log_bin';"
docker exec mysql mysql -u root -p'starrocks_demo_pw1#' -e "SHOW VARIABLES LIKE 'gtid_mode';"
```

### StarRocks 연결 오류

```bash
# StarRocks 상태 확인
docker exec starrocks-fe mysql -u root -h starrocks-fe -P 9030 -e "SHOW FRONTENDS\G"

# BE 상태 확인
docker exec starrocks-fe mysql -u root -h starrocks-fe -P 9030 -e "SHOW BACKENDS\G"
```

### 데이터가 동기화되지 않는 경우

```sql
-- RisingWave에서 CDC 테이블 데이터 확인
SELECT COUNT(*) FROM orders_cdc;

-- Sink 상태 확인
SHOW SINKS;

-- 에러 로그 확인
-- Dashboard에서 Streaming Jobs 상태 확인
```

---

## 정리

```bash
# RisingWave 포함 전체 종료
docker compose --profile be --profile risingwave down

# 볼륨까지 삭제 (데이터 초기화)
docker compose --profile be --profile risingwave down -v
```

---

## 참고 자료

- [RisingWave 공식 문서](https://docs.risingwave.com/)
- [RisingWave MySQL CDC 커넥터](https://docs.risingwave.com/docs/current/ingest-from-mysql-cdc/)
- [RisingWave StarRocks Sink](https://docs.risingwave.com/docs/current/sink-to-starrocks/)
- [RisingWave GitHub](https://github.com/risingwavelabs/risingwave)

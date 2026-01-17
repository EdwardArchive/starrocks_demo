# Task 스케줄링을 사용한 MySQL → StarRocks 데이터 동기화

## 개요

이 가이드는 StarRocks의 External Catalog와 Task 스케줄링을 사용하여 MySQL 데이터를 StarRocks로 동기화하는 방법을 설명합니다.

### Flink CDC 방식과의 차이점

| 항목 | Task 스케줄링 | Flink CDC |
|-----|--------------|-----------|
| 동기화 방식 | 폴링 (주기적 쿼리) | 실시간 binlog 캡처 |
| 지연 시간 | 설정된 주기 (예: 5분) | 밀리초 단위 |
| 스키마 변경 | 수동 처리 필요 | 자동 전파 (CDC 3.0+) |
| 추가 리소스 | 없음 (StarRocks만 사용) | Flink 클러스터 필요 |
| 적합한 사용 사례 | 준실시간 분석, 배치 동기화 | 실시간 분석, 이벤트 처리 |

---

## Step 1: MySQL 데이터 확인

MySQL이 초기화되면 자동으로 샘플 데이터가 생성됩니다.

> **참고**: MySQL 초기화 스크립트는 볼륨이 처음 생성될 때만 실행됩니다. 기존 볼륨이 있는 상태에서 다시 시작하면 초기화가 실행되지 않습니다. 데이터를 초기화하려면 `docker compose --profile <mode> down -v`로 볼륨을 삭제하세요.

```bash
# MySQL 접속
mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#'
```

```sql
-- 데이터베이스 확인
USE demo_db;

-- 테이블 확인
SHOW TABLES;

-- 데이터 확인 (1005개 레코드)
SELECT COUNT(*) FROM products;

-- 카테고리별 통계
SELECT category, COUNT(*) as cnt, AVG(price) as avg_price
FROM products
GROUP BY category;
```

---

## Step 2: StarRocks External Catalog 생성

StarRocks에서 MySQL 카탈로그를 생성합니다.

```bash
# StarRocks 접속
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'
```

```sql
-- MySQL External Catalog 생성
-- 주의: MySQL 8.0의 경우 allowPublicKeyRetrieval=true&useSSL=false 옵션 필요
CREATE EXTERNAL CATALOG IF NOT EXISTS mysql_catalog
PROPERTIES (
    "type" = "jdbc",
    "user" = "root",
    "password" = "starrocks_demo_pw1#",
    "jdbc_uri" = "jdbc:mysql://mysql:3306?allowPublicKeyRetrieval=true&useSSL=false",
    "driver_url" = "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar",
    "driver_class" = "com.mysql.cj.jdbc.Driver"
);

-- Catalog 확인
SHOW CATALOGS;

-- MySQL 데이터베이스 확인
SHOW DATABASES FROM mysql_catalog;

-- MySQL 테이블 직접 조회 (Federation Query)
SELECT * FROM mysql_catalog.demo_db.products LIMIT 10;
```

---

## Step 3: CDC 동기화 테이블 생성

데이터 동기화를 위한 Primary Key 테이블을 생성합니다.

```sql
-- 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- Primary Key 테이블 생성
CREATE TABLE IF NOT EXISTS products_sync (
    product_id INT,
    product_name VARCHAR(100),
    category VARCHAR(100),
    price DECIMAL(10, 2),
    stock_quantity INT,
    last_updated DATETIME,
    sync_time DATETIME DEFAULT CURRENT_TIMESTAMP
)
PRIMARY KEY (product_id)
DISTRIBUTED BY HASH(product_id) BUCKETS 3
PROPERTIES (
    "replication_num" = "1",
    "enable_persistent_index" = "true"
);

-- 초기 데이터 동기화 (전체 로드)
INSERT INTO analytics_db.products_sync
    (product_id, product_name, category, price, stock_quantity, last_updated, sync_time)
SELECT
    product_id, product_name, category, price, stock_quantity, last_updated, NOW()
FROM mysql_catalog.demo_db.products;

-- 동기화 확인
SELECT COUNT(*) FROM analytics_db.products_sync;
```

---

## Step 4: 주기적 동기화 Task 설정

변경된 데이터를 주기적으로 동기화하는 Task를 생성합니다.

```sql
-- 스케줄 Task 생성 (10초마다 실행)
SUBMIT TASK sync_products_scheduled
SCHEDULE EVERY(INTERVAL 10 SECOND)
AS INSERT INTO analytics_db.products_sync
    (product_id, product_name, category, price, stock_quantity, last_updated, sync_time)
SELECT
    product_id, product_name, category, price, stock_quantity, last_updated, NOW()
FROM mysql_catalog.demo_db.products
WHERE last_updated >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE);

-- Task 확인
SELECT * FROM information_schema.tasks;
```

### Task 관리

```sql
-- Task 목록 조회
SHOW TASKS;

-- Task 실행 이력 조회
SELECT * FROM information_schema.task_runs ORDER BY create_time DESC LIMIT 10;

-- Task 삭제
DROP TASK sync_products_scheduled;
```

---

## Step 5: 실시간 변경 테스트

MySQL에서 데이터를 변경하고 StarRocks에서 확인합니다.

### MySQL에서 데이터 변경

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#' demo_db
```

```sql
-- 가격 업데이트
UPDATE products SET price = price * 1.1 WHERE product_id = 1;

-- 신규 데이터 추가
INSERT INTO products (product_name, category, price, stock_quantity)
VALUES ('테스트 상품', '테스트', 99999, 100);

-- 변경 확인
SELECT * FROM products WHERE product_id IN (1, (SELECT MAX(product_id) FROM products));
```

### StarRocks에서 확인

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'
```

```sql
-- MySQL(External Catalog) 데이터 직접 조회 (실시간 - Federation Query)
SELECT * FROM mysql_catalog.demo_db.products WHERE product_id = 1
UNION ALL
SELECT * FROM mysql_catalog.demo_db.products
WHERE product_id = (SELECT MAX(product_id) FROM mysql_catalog.demo_db.products);

-- 동기화된 테이블에서 확인 (Task 주기 후 반영)
SELECT * FROM analytics_db.products_sync
WHERE product_id IN (1, (SELECT MAX(product_id) FROM analytics_db.products_sync));
```

---

## 트러블슈팅

### External Catalog 생성 실패

```sql
-- MySQL 연결 테스트
SELECT * FROM mysql_catalog.demo_db.products LIMIT 1;
```

오류 발생 시:
- MySQL 컨테이너가 실행 중인지 확인: `docker ps | grep mysql`
- 네트워크 연결 확인: `docker exec starrocks-fe ping mysql`

### RSA Public Key 오류

```
RSA public key is not available client side
```

해결: JDBC URI에 `allowPublicKeyRetrieval=true&useSSL=false` 옵션 추가

### Task가 실행되지 않는 경우

```sql
-- Task 상태 확인
SELECT * FROM information_schema.tasks WHERE task_name = 'sync_products_scheduled';

-- 최근 실행 이력 확인
SELECT * FROM information_schema.task_runs
WHERE task_name = 'sync_products_scheduled'
ORDER BY create_time DESC LIMIT 5;
```

---

## 참고 자료

- [StarRocks External Catalog (JDBC)](https://docs.starrocks.io/docs/data_source/catalog/jdbc_catalog/)
- [StarRocks Primary Key 테이블](https://docs.starrocks.io/docs/table_design/table_types/primary_key_table/)
- [StarRocks Task 스케줄링](https://docs.starrocks.io/docs/loading/Etl_using_task/)

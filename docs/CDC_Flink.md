# Flink CDC를 사용한 MySQL → StarRocks 실시간 동기화

## 개요

이 가이드는 Apache Flink CDC를 사용하여 MySQL 데이터를 StarRocks로 실시간 동기화하는 방법을 설명합니다.

### Task 방식과의 차이점

| 항목 | Task 스케줄링 (기존) | Flink CDC |
|-----|---------------------|-----------|
| 동기화 방식 | 폴링 (5분 주기) | 실시간 binlog 캡처 |
| 지연 시간 | 최대 5분 | 밀리초 단위 |
| 스키마 변경 | 수동 처리 필요 | 자동 전파 (CDC 3.0+) |
| 리소스 | StarRocks Task만 사용 | Flink 클러스터 필요 |

### Flink CDC 방식 비교

| 항목 | YAML 파이프라인 | Flink SQL |
|-----|----------------|-----------|
| 버전 | Flink CDC 3.0+ | Flink CDC 2.x+ |
| 스키마 자동 생성 | 지원 | 미지원 (수동 생성) |
| 스키마 변경 전파 | 자동 지원 | 미지원 |
| 다중 테이블 | 패턴 지원 (`db.*`) | 테이블별 정의 필요 |
| 데이터 변환 | 제한적 | 집계/필터/조인 가능 |

---

## Step 1: 환경 시작

### BE 모드 + Flink

```bash
docker compose --profile be --profile flink up -d --build
```

### CN 모드 + Flink

```bash
docker compose --profile cn --profile flink up -d --build
```

### 서비스 상태 확인

```bash
docker compose --profile be --profile flink ps
```

모든 서비스가 healthy 상태가 될 때까지 대기합니다 (약 1-2분).

---

## Step 2: Flink CDC 파이프라인 시작 (YAML 방식)

### 파이프라인 설정 파일

`cdc/flink/pipelines/mysql-to-starrocks.yaml` 파일이 CDC 파이프라인을 정의합니다:

```yaml
source:                                    # MySQL CDC 소스 설정
  type: mysql
  hostname: mysql                          # MySQL 호스트
  port: 3306
  username: root
  password: "starrocks_demo_pw1#"
  tables: demo_db.products                 # 동기화할 테이블 (패턴 가능: demo_db.*)
  server-id: 5400-5404                     # binlog 읽기용 서버 ID 범위
  server-time-zone: UTC
  jdbc.properties.allowPublicKeyRetrieval: true
  jdbc.properties.useSSL: false

sink:                                      # StarRocks 싱크 설정
  type: starrocks
  jdbc-url: jdbc:mysql://starrocks-fe:9030 # 쿼리용 (MySQL 프로토콜)
  load-url: starrocks-fe:8030              # 데이터 로딩용 (Stream Load HTTP)
  username: root
  password: "starrocks_demo_pw1#"
  table.create.properties.replication_num: 1

pipeline:                                  # 파이프라인 설정
  name: MySQL to StarRocks CDC Demo
  parallelism: 2
```

### 파이프라인 제출

```bash
docker exec flink-jobmanager flink-cdc.sh /opt/flink-cdc/pipelines/mysql-to-starrocks.yaml
```

`flink-cdc.sh`가 YAML 파일을 읽어 자동으로:
1. MySQL binlog를 캡처하는 소스 생성
2. StarRocks에 테이블 자동 생성 (없는 경우)
3. 실시간 데이터 동기화 시작

### Flink Web UI에서 확인

브라우저에서 http://localhost:8082 접속

- Running Jobs 탭에서 "MySQL to StarRocks CDC Demo" 확인
- 상태가 RUNNING이면 정상

---

## Step 3: 실시간 동기화 테스트

### MySQL에서 데이터 변경

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#' demo_db
```

```sql
-- 기존 데이터 수정
UPDATE products SET price = 999999 WHERE product_id = 1;

-- 신규 데이터 추가
INSERT INTO products (product_name, category, price, stock_quantity)
VALUES ('Flink CDC Test', 'Test', 12345, 100);

-- 데이터 삭제
DELETE FROM products WHERE product_name = 'Flink CDC Test';
```

### StarRocks에서 확인

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'
```

```sql
-- Flink CDC가 자동 생성한 테이블 확인
SHOW DATABASES;
USE demo_db;
SHOW TABLES;

-- 변경된 데이터 확인
SELECT * FROM products WHERE product_id = 1;
SELECT * FROM products ORDER BY product_id DESC LIMIT 5;
```

---

## Step 4: 파이프라인 관리

### 실행 중인 Job 확인

```bash
docker exec flink-jobmanager flink list
```

### Job 중지

```bash
docker exec flink-jobmanager flink cancel <JOB_ID>
```

### 로그 확인

```bash
docker logs -f flink-jobmanager
docker logs -f flink-taskmanager
```

---

## 트러블슈팅

### Flink Job이 시작되지 않는 경우

```bash
# TaskManager 로그 확인
docker logs flink-taskmanager

# MySQL binlog 설정 확인
docker exec mysql mysql -u root -p'starrocks_demo_pw1#' -e "SHOW VARIABLES LIKE 'log_bin';"
```

### StarRocks 연결 오류

```bash
# StarRocks FE 상태 확인
docker exec starrocks-fe mysql -u root -h starrocks-fe -P 9030 -e "SHOW FRONTENDS\G"

# BE/CN 상태 확인 (BE 모드)
docker exec starrocks-fe mysql -u root -h starrocks-fe -P 9030 -e "SHOW BACKENDS\G"
```

---

## 대안: Flink SQL 방식

YAML 파이프라인 대신 Flink SQL을 사용하여 CDC를 구성할 수 있습니다.
데이터 변환, 집계, 필터링이 필요한 경우 SQL 방식이 더 유연합니다.

### Flink SQL Client 접속

```bash
docker exec -it flink-jobmanager /opt/flink/bin/sql-client.sh
```

### 1. MySQL CDC 소스 테이블 정의

```sql
CREATE TABLE products_source (
    product_id INT NOT NULL,
    product_name STRING,
    category STRING,
    price DECIMAL(10, 2),
    stock_quantity INT,
    last_updated TIMESTAMP(3),
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql',
    'port' = '3306',
    'username' = 'root',
    'password' = 'starrocks_demo_pw1#',
    'database-name' = 'demo_db',
    'table-name' = 'products',
    'server-id' = '5401-5404',
    'jdbc.properties.allowPublicKeyRetrieval' = 'true',
    'jdbc.properties.useSSL' = 'false'
);
```

### 2. StarRocks 싱크 테이블 정의

```sql
CREATE TABLE products_sink (
    product_id INT NOT NULL,
    product_name STRING,
    category STRING,
    price DECIMAL(10, 2),
    stock_quantity INT,
    last_updated TIMESTAMP(3),
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://starrocks-fe:9030',
    'load-url' = 'starrocks-fe:8030',
    'database-name' = 'demo_db',
    'table-name' = 'products_sql',
    'username' = 'root',
    'password' = 'starrocks_demo_pw1#'
);
```

### 3. 동기화 실행

```sql
-- 단순 복제
INSERT INTO products_sink SELECT * FROM products_source;

-- 또는 변환하면서 동기화
INSERT INTO products_sink
SELECT
    product_id,
    UPPER(product_name) as product_name,  -- 대문자 변환
    category,
    price * 1.1 as price,                  -- 10% 마진 추가
    stock_quantity,
    last_updated
FROM products_source
WHERE price > 100;                         -- 필터링
```

### 4. 집계 동기화 예시

```sql
-- 카테고리별 집계 테이블
CREATE TABLE category_summary_sink (
    category STRING,
    product_count BIGINT,
    avg_price DECIMAL(10, 2),
    total_stock BIGINT,
    PRIMARY KEY (category) NOT ENFORCED
) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://starrocks-fe:9030',
    'load-url' = 'starrocks-fe:8030',
    'database-name' = 'demo_db',
    'table-name' = 'category_summary',
    'username' = 'root',
    'password' = 'starrocks_demo_pw1#'
);

-- 실시간 집계 동기화
INSERT INTO category_summary_sink
SELECT
    category,
    COUNT(*) as product_count,
    AVG(price) as avg_price,
    SUM(stock_quantity) as total_stock
FROM products_source
GROUP BY category;
```

### SQL 방식 주의사항

- StarRocks에 싱크 테이블을 **미리 생성**해야 합니다 (YAML과 달리 자동 생성 안됨)
- 스키마 변경이 자동 전파되지 않습니다
- 테이블마다 별도의 CREATE TABLE 문이 필요합니다

---

## 정리

```bash
# Flink 포함 전체 종료
docker compose --profile be --profile flink down

# 볼륨까지 삭제 (데이터 초기화)
docker compose --profile be --profile flink down -v
```

---

## 참고 자료

- [MySQL to StarRocks Tutorial (Apache Flink CDC)](https://nightlies.apache.org/flink/flink-cdc-docs-master/docs/get-started/quickstart/mysql-to-starrocks/)
- [Realtime synchronization from MySQL (StarRocks Docs)](https://docs.starrocks.io/docs/loading/Flink_cdc_load/)
- [Flink CDC Releases](https://github.com/apache/flink-cdc/releases)

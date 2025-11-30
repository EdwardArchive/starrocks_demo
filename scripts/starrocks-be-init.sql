-- StarRocks BE 모드 초기화 스크립트
-- MySQL CDC 데모용

-- 1. MySQL External Catalog 생성
CREATE EXTERNAL CATALOG IF NOT EXISTS mysql_catalog
PROPERTIES (
    "type" = "jdbc",
    "user" = "root",
    "password" = "StarRocksDemo1!",
    "jdbc_uri" = "jdbc:mysql://mysql:3306?allowPublicKeyRetrieval=true&useSSL=false",
    "driver_url" = "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar",
    "driver_class" = "com.mysql.cj.jdbc.Driver"
);

-- 2. Catalog 확인
SHOW CATALOGS;

-- 3. MySQL 데이터베이스 확인
SHOW DATABASES FROM mysql_catalog;

-- 4. MySQL 테이블 데이터 조회 테스트
SELECT * FROM mysql_catalog.demo_db.products LIMIT 10;

-- 5. 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- 6. MySQL 데이터를 동기화할 StarRocks Primary Key 테이블
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

-- 7. 초기 데이터 동기화 (전체 로드)
INSERT INTO analytics_db.products_sync (product_id, product_name, category, price, stock_quantity, last_updated, sync_time)
SELECT
    product_id,
    product_name,
    category,
    price,
    stock_quantity,
    last_updated,
    NOW() as sync_time
FROM mysql_catalog.demo_db.products;

-- 8. 주기적 동기화 Task 생성 (5분마다 실행)
SUBMIT TASK sync_products_scheduled
SCHEDULE EVERY(INTERVAL 5 MINUTE)
AS INSERT INTO analytics_db.products_sync (product_id, product_name, category, price, stock_quantity, last_updated, sync_time)
SELECT
    product_id,
    product_name,
    category,
    price,
    stock_quantity,
    last_updated,
    NOW() as sync_time
FROM mysql_catalog.demo_db.products
WHERE last_updated >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE);

-- 9. Task 확인
SHOW TASKS;

-- 10. 동기화 결과 확인
SELECT COUNT(*) as total_synced FROM analytics_db.products_sync;
SELECT * FROM analytics_db.products_sync ORDER BY product_id LIMIT 10;

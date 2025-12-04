-- StarRocks 테이블 준비 스크립트 (Risingwave Sink용)
-- Risingwave 싱크 대상 테이블을 먼저 생성해야 합니다

-- 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- Risingwave CDC 싱크용 Primary Key 테이블 생성
CREATE TABLE IF NOT EXISTS products_risingwave_sync (
    product_id INT,
    product_name VARCHAR(100),
    category VARCHAR(100),
    price DECIMAL(10, 2),
    stock_quantity INT,
    last_updated DATETIME
)
PRIMARY KEY (product_id)
DISTRIBUTED BY HASH(product_id) BUCKETS 3
PROPERTIES (
    "replication_num" = "1",
    "enable_persistent_index" = "true"
);

-- Risingwave Materialized View 싱크용 테이블 생성
CREATE TABLE IF NOT EXISTS category_stats_risingwave (
    category VARCHAR(100),
    product_count BIGINT,
    avg_price DECIMAL(12, 2),
    total_stock BIGINT,
    last_updated DATETIME
)
PRIMARY KEY (category)
DISTRIBUTED BY HASH(category) BUCKETS 3
PROPERTIES (
    "replication_num" = "1"
);

-- 테이블 확인
SHOW TABLES FROM analytics_db LIKE '%risingwave%';

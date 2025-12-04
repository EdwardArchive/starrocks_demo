-- StarRocks 테이블 준비 스크립트 (Flink CDC용)
-- Flink CDC 싱크 대상 테이블을 먼저 생성해야 합니다

-- 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- Flink CDC 싱크용 Primary Key 테이블 생성
CREATE TABLE IF NOT EXISTS products_flink_sync (
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

-- 테이블 확인
SHOW TABLES FROM analytics_db;
DESC analytics_db.products_flink_sync;

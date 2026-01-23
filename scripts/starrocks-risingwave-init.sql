-- StarRocks RisingWave 모드 초기화 스크립트
-- RisingWave CDC 데모용

-- 1. 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- 2. orders 테이블 동기화용 StarRocks Primary Key 테이블
-- RisingWave Sink에서 데이터를 UPSERT/DELETE 합니다
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

-- 3. 테이블 구조 확인
DESCRIBE analytics_db.orders_sync;

-- 4. 초기 데이터 확인 (RisingWave 파이프라인 설정 후 데이터가 채워집니다)
SELECT COUNT(*) as total_synced FROM analytics_db.orders_sync;

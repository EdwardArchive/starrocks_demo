-- RisingWave CDC 파이프라인 설정 스크립트
-- MySQL -> RisingWave -> StarRocks 실시간 동기화

-- ===========================================
-- Step 1: MySQL CDC 소스 생성
-- ===========================================
-- MySQL binlog를 읽어서 CDC 이벤트를 캡처합니다
CREATE SOURCE IF NOT EXISTS mysql_cdc_source WITH (
    connector = 'mysql-cdc',
    hostname = 'mysql',
    port = '3306',
    username = 'root',
    password = 'starrocks_demo_pw1#',
    database.name = 'demo_db',
    server.id = '5501'
);

-- ===========================================
-- Step 2: CDC 테이블 생성 (orders)
-- ===========================================
-- MySQL의 orders 테이블을 RisingWave 테이블로 매핑합니다
-- 자동 스키마 매핑 사용 (*)
CREATE TABLE IF NOT EXISTS orders_cdc (
    *,
    PRIMARY KEY (order_id)
) FROM mysql_cdc_source TABLE 'demo_db.orders';

-- ===========================================
-- Step 3: StarRocks Sink 생성
-- ===========================================
-- RisingWave에서 캡처한 CDC 데이터를 StarRocks로 실시간 전송합니다
-- TIMESTAMPTZ를 TIMESTAMP로 변환하여 전송
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

-- ===========================================
-- 파이프라인 상태 확인 쿼리
-- ===========================================

-- 소스 확인
-- SHOW SOURCES;

-- 테이블 확인
-- SHOW TABLES;

-- Sink 확인
-- SHOW SINKS;

-- CDC 데이터 샘플 조회
-- SELECT * FROM orders_cdc LIMIT 10;

-- 데이터 건수 확인
-- SELECT COUNT(*) FROM orders_cdc;

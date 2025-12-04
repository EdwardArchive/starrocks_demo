-- Risingwave CDC Pipeline: MySQL to StarRocks
-- 이 스크립트는 Risingwave 초기화 컨테이너에서 자동 실행됩니다

-- 1. MySQL CDC 소스 테이블 생성
CREATE TABLE IF NOT EXISTS products_cdc (
    product_id INT PRIMARY KEY,
    product_name VARCHAR,
    category VARCHAR,
    price NUMERIC,
    stock_quantity INT,
    last_updated TIMESTAMPTZ
) WITH (
    connector = 'mysql-cdc',
    hostname = 'mysql',
    port = '3306',
    username = 'root',
    password = 'StarRocksDemo1!',
    database.name = 'demo_db',
    table.name = 'products',
    server.id = '5500'
);

-- 2. 카테고리별 집계 Materialized View 생성
CREATE MATERIALIZED VIEW IF NOT EXISTS products_by_category AS
SELECT
    category,
    COUNT(*) AS product_count,
    AVG(price)::NUMERIC(12,2) AS avg_price,
    SUM(stock_quantity) AS total_stock,
    MAX(last_updated) AS last_updated
FROM products_cdc
GROUP BY category;

-- 참고: StarRocks Sink는 현재 Risingwave에서 직접 지원되지 않을 수 있습니다.
-- 대안으로 JDBC Sink 또는 Kafka를 통한 연동을 고려하세요.
-- 아래는 예시용 Sink 정의입니다 (실제 동작 여부는 Risingwave 버전에 따라 다름)

-- 3. 데이터 확인 쿼리
-- SELECT * FROM products_cdc LIMIT 10;
-- SELECT * FROM products_by_category;

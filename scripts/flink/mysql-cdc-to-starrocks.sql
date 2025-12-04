-- Flink SQL: MySQL CDC to StarRocks
-- 이 스크립트를 Flink SQL Client에서 실행하세요
-- docker exec -it flink-sql-client ./bin/sql-client.sh

-- 필요한 JAR 파일이 로드되어 있는지 확인
-- config/flink/lib/ 디렉토리의 README.md 참조

-- 1. MySQL CDC 소스 테이블 생성
CREATE TABLE mysql_products (
    product_id INT,
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
    'password' = 'StarRocksDemo1!',
    'database-name' = 'demo_db',
    'table-name' = 'products',
    'server-id' = '5400-5404',
    'server-time-zone' = 'UTC'
);

-- 2. StarRocks Sink 테이블 생성
CREATE TABLE starrocks_products_sink (
    product_id INT,
    product_name STRING,
    category STRING,
    price DECIMAL(10, 2),
    stock_quantity INT,
    last_updated TIMESTAMP(3),
    sync_time TIMESTAMP(3),
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://starrocks-fe:9030',
    'load-url' = 'starrocks-fe:8030',
    'database-name' = 'analytics_db',
    'table-name' = 'products_flink_sync',
    'username' = 'root',
    'password' = '',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'true',
    'sink.buffer-flush.interval-ms' = '15000',
    'sink.parallelism' = '1'
);

-- 3. CDC 스트리밍 Job 실행
-- 이 쿼리는 MySQL의 변경사항을 실시간으로 StarRocks에 동기화합니다
INSERT INTO starrocks_products_sink
SELECT
    product_id,
    product_name,
    category,
    price,
    stock_quantity,
    last_updated,
    CURRENT_TIMESTAMP AS sync_time
FROM mysql_products;

-- 참고: 이 INSERT 문을 실행하면 Flink Job이 시작됩니다
-- Job 상태는 http://localhost:8081 에서 확인할 수 있습니다

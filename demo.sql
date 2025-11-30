CREATE DATABASE IF NOT EXISTS demo_db;
USE demo_db;

-- 샘플 테이블 생성
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2),
    stock_quantity INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 샘플 데이터 삽입
INSERT INTO products (product_name, category, price, stock_quantity) VALUES
('노트북', '전자기기', 1200000.00, 50),
('무선 마우스', '전자기기', 35000.00, 200),
('기계식 키보드', '전자기기', 89000.00, 150),
('모니터 27인치', '전자기기', 350000.00, 80),
('USB 허브', '액세서리', 25000.00, 300);

-- 1000개의 랜덤데이터
INSERT INTO products (product_name, category, price, stock_quantity)
SELECT 
    CONCAT('Product_', seq.n) as product_name,
    ELT(1 + (seq.n % 5), '전자기기', '액세서리', '가구', '조명', '소모품') as category,
    ROUND(5000 + RAND() * 1995000, -2) as price,
    FLOOR(5 + RAND() * 995) as stock_quantity
FROM (
    SELECT a.N + b.N * 10 + c.N * 100 + 1 as n
    FROM 
        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
) seq;



-- 카테고리별 일괄 가격 인상 (10%)
UPDATE products 
SET price = price * 1.10 
WHERE category = '전자기기';

-- 재고 부족 상품 표시
UPDATE products 
SET category = CONCAT(category, ' [재고부족]')
WHERE stock_quantity < 100;
CREATE EXTERNAL CATALOG mysql_catalog
PROPERTIES (
    "type" = "jdbc",
    "user" = "root",
    "password" = "imply",
    "jdbc_uri" = "jdbc:mysql://192.168.0.236:3306",
    "driver_url" = "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar",
    "driver_class" = "com.mysql.cj.jdbc.Driver"
);

-- Catalog 확인
SHOW CATALOGS;

-- MySQL 데이터베이스 확인
SHOW DATABASES FROM mysql_catalog;

-- MySQL 테이블 데이터 조회 테스트
SELECT * FROM mysql_catalog.demo_db.products;

CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- MySQL 데이터를 동기화할 StarRocks Primary Key 테이블
CREATE TABLE products_sync (
    product_id INT,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2),
    stock_quantity INT,
    last_updated DATETIME,
    sync_time DATETIME DEFAULT CURRENT_TIMESTAMP -- sync된 시점
)
PRIMARY KEY (product_id)
DISTRIBUTED BY HASH(product_id) BUCKETS 3
PROPERTIES (
    "replication_num" = "1",
    "enable_persistent_index" = "true"
);

DROP TASK sync_products_scheduled;

--TASK 생성
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
    NOW() as sync_time -- 추가컬럼
FROM mysql_catalog.demo_db.products
WHERE last_updated >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE); -- MySQL 부하를 줄이기 위한 방법 1

--결과 확인
SELECT * FROM analytics_db.products_sync order by product_id;
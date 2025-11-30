-- MySQL 초기화 스크립트
-- StarRocks CDC 데모용

-- 사용자 생성
CREATE USER IF NOT EXISTS 'heidi'@'%' IDENTIFIED BY 'StarRocksDemo1!';
GRANT ALL PRIVILEGES ON *.* TO 'heidi'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- 데이터베이스 생성
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

-- 1000개의 랜덤 데이터 생성
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

-- 초기 데이터 확인
SELECT COUNT(*) as total_products FROM products;
SELECT category, COUNT(*) as count, AVG(price) as avg_price FROM products GROUP BY category;

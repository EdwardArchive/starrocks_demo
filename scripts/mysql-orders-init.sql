-- MySQL orders 테이블 초기화 스크립트
-- RisingWave CDC 데모용

USE demo_db;

-- orders 테이블 생성
CREATE TABLE IF NOT EXISTS orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_name VARCHAR(100) NOT NULL,
    product_id INT NOT NULL,
    quantity INT DEFAULT 1,
    total_amount DECIMAL(12, 2),
    order_status ENUM('pending', 'confirmed', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    shipping_address VARCHAR(255),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 샘플 데이터 100건 삽입
INSERT INTO orders (customer_name, product_id, quantity, total_amount, order_status, shipping_address) VALUES
('김철수', 1, 1, 1200000.00, 'delivered', '서울시 강남구 테헤란로 123'),
('이영희', 2, 2, 70000.00, 'shipped', '서울시 서초구 반포대로 456'),
('박민수', 3, 1, 89000.00, 'confirmed', '경기도 성남시 분당구 정자동 789'),
('최지영', 4, 1, 350000.00, 'pending', '서울시 송파구 올림픽로 321'),
('정대호', 5, 3, 75000.00, 'delivered', '인천시 남동구 논현동 654'),
('강수진', 1, 2, 2400000.00, 'shipped', '대전시 유성구 봉명동 111'),
('윤미라', 2, 5, 175000.00, 'confirmed', '대구시 달서구 월성동 222'),
('송재현', 3, 2, 178000.00, 'pending', '부산시 해운대구 우동 333'),
('임서연', 4, 1, 350000.00, 'delivered', '광주시 서구 치평동 444'),
('한동훈', 5, 4, 100000.00, 'cancelled', '울산시 남구 삼산동 555');

-- 추가 90건의 랜덤 데이터 생성
INSERT INTO orders (customer_name, product_id, quantity, total_amount, order_status, shipping_address)
SELECT
    CONCAT(
        ELT(1 + (seq.n % 10), '김', '이', '박', '최', '정', '강', '윤', '송', '임', '한'),
        ELT(1 + ((seq.n DIV 10) % 10), '철수', '영희', '민수', '지영', '대호', '수진', '미라', '재현', '서연', '동훈')
    ) as customer_name,
    1 + (seq.n % 5) as product_id,
    1 + (seq.n % 5) as quantity,
    ROUND((1 + (seq.n % 5)) * (10000 + RAND() * 1000000), -2) as total_amount,
    ELT(1 + (seq.n % 5), 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled') as order_status,
    CONCAT(
        ELT(1 + (seq.n % 8), '서울시', '경기도', '인천시', '대전시', '대구시', '부산시', '광주시', '울산시'),
        ' ',
        ELT(1 + ((seq.n DIV 8) % 5), '강남구', '서초구', '송파구', '마포구', '영등포구'),
        ' ',
        ELT(1 + ((seq.n DIV 40) % 5), '테헤란로', '반포대로', '올림픽로', '양재대로', '도산대로'),
        ' ',
        (100 + seq.n)
    ) as shipping_address
FROM (
    SELECT a.N + b.N * 10 as n
    FROM
        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
        (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
    LIMIT 90
) seq;

-- 초기 데이터 확인
SELECT COUNT(*) as total_orders FROM orders;
SELECT order_status, COUNT(*) as count, SUM(total_amount) as total_revenue
FROM orders
GROUP BY order_status;

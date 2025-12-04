# Risingwave CDC 스크립트

## 개요

Risingwave는 스트리밍 데이터베이스로, MySQL CDC를 직접 지원하며 Materialized View를 통해 실시간 집계가 가능합니다.

## 사용 방법

### 1. Risingwave 프로필 시작
```bash
docker compose --profile be --profile risingwave up -d
```

### 2. Risingwave 연결
```bash
psql -h localhost -p 4566 -U root -d dev
```

### 3. CDC 상태 확인
```sql
-- CDC 테이블 확인
SELECT * FROM products_cdc LIMIT 10;

-- Materialized View 확인
SELECT * FROM products_by_category;
```

## 파일 설명

- `starrocks-prepare.sql`: StarRocks 싱크 테이블 생성 (init 컨테이너에서 실행)
- `risingwave-init.sql`: Risingwave CDC 소스 및 MV 생성 (init 컨테이너에서 실행)

## 아키텍처

```
MySQL (binlog)
    ↓
Risingwave CDC Source (products_cdc)
    ↓
Materialized View (products_by_category)
    ↓
(향후) StarRocks Sink
```

## 테스트

### MySQL에서 데이터 변경
```sql
mysql -h 127.0.0.1 -P 3306 -u root -p'StarRocksDemo1!' demo_db -e "
INSERT INTO products (product_name, category, price, stock_quantity)
VALUES ('Risingwave Test', '테스트', 10000, 50);
"
```

### Risingwave에서 실시간 확인
```sql
psql -h localhost -p 4566 -U root -d dev -c "
SELECT * FROM products_cdc WHERE product_name = 'Risingwave Test';
"
```

### Materialized View 확인
```sql
psql -h localhost -p 4566 -U root -d dev -c "
SELECT * FROM products_by_category;
"
```

## 참고

- Risingwave는 PostgreSQL 프로토콜을 사용합니다
- server.id는 5500을 사용합니다 (Flink CDC와 충돌 방지)
- Materialized View는 자동으로 증분 업데이트됩니다
- StarRocks로의 직접 Sink는 Risingwave 버전에 따라 지원 여부가 다릅니다

## 트러블슈팅

### CDC 연결 실패
```bash
# MySQL binlog 설정 확인
docker exec mysql mysql -u root -pStarRocksDemo1! -e "SHOW MASTER STATUS;"
```

### Risingwave 로그 확인
```bash
docker logs risingwave
```

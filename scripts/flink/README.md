# Flink CDC 스크립트

## 사전 준비

1. Flink 커넥터 JAR 파일 다운로드 (config/flink/lib/README.md 참조)
2. StarRocks 테이블 생성

## 사용 방법

### 1. StarRocks 테이블 준비
```bash
mysql -h 127.0.0.1 -P 9030 -u root < scripts/flink/starrocks-prepare.sql
```

### 2. Flink SQL Client 접속
```bash
docker exec -it flink-sql-client ./bin/sql-client.sh
```

### 3. CDC Job 실행
Flink SQL Client에서 `scripts/flink/mysql-cdc-to-starrocks.sql` 내용을 순서대로 실행

### 4. Job 모니터링
- Flink Web UI: http://localhost:8081
- Running Jobs에서 CDC Job 상태 확인

## 파일 설명

- `mysql-cdc-to-starrocks.sql`: Flink SQL CDC 파이프라인 정의
- `starrocks-prepare.sql`: StarRocks 싱크 테이블 생성 스크립트

## 테스트

### MySQL에서 데이터 변경
```sql
mysql -h 127.0.0.1 -P 3306 -u root -p'StarRocksDemo1!' demo_db -e "
UPDATE products SET price = price + 100 WHERE product_id = 1;
"
```

### StarRocks에서 확인
```sql
mysql -h 127.0.0.1 -P 9030 -u root -e "
SELECT * FROM analytics_db.products_flink_sync WHERE product_id = 1;
"
```

## 참고

- Flink CDC는 MySQL binlog를 읽어 변경사항을 감지합니다
- MySQL의 binlog_format=ROW, gtid_mode=ON 설정이 필요합니다 (이미 설정됨)
- server-id는 5400-5404 범위를 사용합니다 (다른 CDC와 충돌 방지)

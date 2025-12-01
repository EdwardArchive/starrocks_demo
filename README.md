MySQL에서 StarRocks로의 데이터 동기화(CDC) 데모 환경입니다-TASK를 활용한.
 Docker Compose를 사용하여 손쉽게 구축할 수 있습니다.

---

## **개요**

이 데모는 다음을 검증합니다:

- MySQL에서 StarRocks로의 데이터 동기화
- StarRocks External Catalog를 통한 MySQL 연결
- Primary Key 테이블을 활용한 CDC 구현
- 스케줄 Task를 통한 주기적 동기화

### **지원 모드**

| 모드 | 설명 | 적합한 사용 사례 |
| --- | --- | --- |
| **BE (Backend)** | 로컬 디스크 기반 스토리지 | 고성능 OLAP, 낮은 지연 |
| **CN (Compute Node)** | S3/MinIO 오브젝트 스토리지 | Data Lake 통합, 탄력적 확장 |

---

## **사전 요구사항**

- Docker 20.10 이상
- Docker Compose v2.0 이상
- 최소 8GB RAM
- 최소 20GB 디스크 공간

### **버전 확인**

```bash
docker --version
docker compose version

```

---

## **GitHub에서 시작하기**

### **프로젝트 클론**

```bash
# GitHub에서 프로젝트 클론
git clone https://github.com/your-username/starrocks_demo.git

# 프로젝트 디렉토리로 이동
cd starrocks_demo
```

### **디렉토리 구조 확인**

```bash
# 파일 구조 확인
ls -la
```

클론 후 다음 파일들이 존재하는지 확인하세요:
- `docker-compose.yml` - Docker Compose 설정
- `config/` - 각 서비스별 설정 파일
- `scripts/` - 초기화 SQL 스크립트

### **즉시 실행**

프로젝트 클론 후 추가 설정 없이 바로 실행할 수 있습니다:

```bash
# BE 모드로 즉시 실행
docker compose --profile be up -d

# 또는 CN 모드로 즉시 실행
docker compose --profile cn up -d
```

---

## **빠른 시작**

### **BE 모드 실행**

로컬 디스크 기반의 전통적인 StarRocks 아키텍처입니다.

```bash
# 1. BE 모드로 실행
docker compose --profile be up -d

# 2. 서비스 상태 확인
docker compose --profile be ps

# 3. FE 로그 확인 (초기화 완료까지 약 1-2분 소요)
docker logs -f starrocks-fe

```

### **CN 모드 실행**

MinIO(S3 호환)를 스토리지로 사용하는 Compute Node 아키텍처입니다.

```bash
# 1. CN 모드로 실행
docker compose --profile cn up -d

# 2. 서비스 상태 확인
docker compose --profile cn ps

# 3. FE 로그 확인
docker logs -f starrocks-fe

```

### **서비스 접속 정보**

| 서비스 | 포트 | 접속 방법 |
| --- | --- | --- |
| MySQL | 3306 | `mysql -h 127.0.0.1 -P 3306 -u root -p'StarRocksDemo1!'` |
| StarRocks (MySQL Protocol) | 9030 | `mysql -h 127.0.0.1 -P 9030 -u root` |
| StarRocks Web UI | 8030 | [http://127.0.0.1:8030](http://127.0.0.1:8030/) |
| MinIO Console (CN모드) | 9001 | [http://127.0.0.1:9001](http://127.0.0.1:9001/) (admin / StarRocksDemo1!_minio) |

---

## **데모 시나리오**

### **Step 1: MySQL 데이터 확인**

MySQL이 초기화되면 자동으로 샘플 데이터가 생성됩니다.

> 참고: MySQL 초기화 스크립트는 볼륨이 처음 생성될 때만 실행됩니다. 기존 볼륨이 있는 상태에서 다시 시작하면 초기화가 실행되지 않습니다. 데이터를 초기화하려면 docker compose --profile <mode> down -v로 볼륨을 삭제하세요.
> 

```bash
# MySQL 접속
mysql -h 127.0.0.1 -P 3306 -u root -p'StarRocksDemo1!'
```

```sql
-- 데이터베이스 확인
USE demo_db;

-- 테이블 확인
SHOW TABLES;

-- 데이터 확인 (1005개 레코드)
SELECT COUNT(*) FROM products;

-- 카테고리별 통계
SELECT category, COUNT(*) as cnt, AVG(price) as avg_price
FROM products
GROUP BY category;
```

### **Step 2: StarRocks External Catalog 생성**

StarRocks에서 MySQL 카탈로그를 생성합니다.

```bash
# StarRocks 접속
mysql -h 127.0.0.1 -P 9030 -u root
```

```sql
-- MySQL External Catalog 생성-- 주의: MySQL 8.0의 경우 allowPublicKeyRetrieval=true&useSSL=false 옵션 필요
CREATE EXTERNAL CATALOG IF NOT EXISTS mysql_catalog
PROPERTIES (
    "type" = "jdbc",
    "user" = "root",
    "password" = "StarRocksDemo1!",
    "jdbc_uri" = "jdbc:mysql://mysql:3306?allowPublicKeyRetrieval=true&useSSL=false",
    "driver_url" = "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar",
    "driver_class" = "com.mysql.cj.jdbc.Driver"
);

-- Catalog 확인
SHOW CATALOGS;

-- MySQL 데이터베이스 확인
SHOW DATABASES FROM mysql_catalog;

-- MySQL 테이블 직접 조회 (Federation Query)
SELECT * FROM mysql_catalog.demo_db.products LIMIT 10;
```

### **Step 3: CDC 동기화 테이블 생성**

데이터 동기화를 위한 Primary Key 테이블을 생성합니다.

```sql
-- 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- Primary Key 테이블 생성
CREATE TABLE IF NOT EXISTS products_sync (
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

-- 초기 데이터 동기화 (전체 로드)
INSERT INTO analytics_db.products_sync
    (product_id, product_name, category, price, stock_quantity, last_updated, sync_time)
SELECT
    product_id, product_name, category, price, stock_quantity, last_updated, NOW()
FROM mysql_catalog.demo_db.products;

-- 동기화 확인
SELECT COUNT(*) FROM analytics_db.products_sync;

```

### **Step 4: 주기적 동기화 Task 설정**

5분마다 변경된 데이터를 동기화하는 Task를 생성합니다.

```sql
-- 스케줄 Task 생성
SUBMIT TASK sync_products_scheduled
SCHEDULE EVERY(INTERVAL 10 SECOND)
AS INSERT INTO analytics_db.products_sync
    (product_id, product_name, category, price, stock_quantity, last_updated, sync_time)
SELECT
    product_id, product_name, category, price, stock_quantity, last_updated, NOW()
FROM mysql_catalog.demo_db.products
WHERE last_updated >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE);

-- Task 확인
SHOW TASKS;
```

### **Step 5: 실시간 변경 테스트**

MySQL에서 데이터를 변경하고 StarRocks에서 확인합니다.

**MySQL에서 데이터 변경:**

```sql
-- MySQL 접속
mysql -h 127.0.0.1 -P 3306 -u root -p'StarRocksDemo1!' demo_db

-- 가격 업데이트
UPDATE products SET price = price * 1.1 WHERE product_id = 1;

-- 신규 데이터 추가
INSERT INTO products (product_name, category, price, stock_quantity)
VALUES ('테스트 상품', '테스트', 99999, 100);

-- 변경 확인
SELECT * FROM products WHERE product_id IN (1, (SELECT MAX(product_id) FROM products));

```

**StarRocks에서 즉시 확인 (Federation Query):**

```sql
-- StarRocks 접속
mysql -h 127.0.0.1 -P 9030 -u root

-- MySQL(External Catalog) 데이터 직접 조회 (실시간)
SELECT * FROM mysql_catalog.demo_db.products WHERE product_id = 1
  UNION ALL
  SELECT * FROM mysql_catalog.demo_db.products WHERE product_id = (SELECT MAX(product_id) FROM mysql_catalog.demo_db.products)

-- 동기화 결과 확인
SELECT * FROM analytics_db.products_sync
WHERE product_id IN (1, (SELECT MAX(product_id) FROM analytics_db.products_sync));
```

---

## **아키텍처 설명**

### **BE 모드 아키텍처**

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   MySQL     │────▶│  StarRocks FE   │────▶│  StarRocks BE   │
│  (Source)   │     │  (Query Engine) │     │ (Local Storage) │
└─────────────┘     └─────────────────┘     └─────────────────┘

```

**특징:**

- 데이터가 BE의 로컬 디스크에 저장
- 높은 I/O 성능
- 단순한 아키텍처

### **CN 모드 아키텍처**

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   MySQL     │────▶│  StarRocks FE   │────▶│  StarRocks CN   │
│  (Source)   │     │  (Query Engine) │     │   (Compute)     │
└─────────────┘     └─────────────────┘     └────────┬────────┘
                                                     │
                                            ┌────────▼────────┐
                                            │     MinIO       │
                                            │  (S3 Storage)   │
                                            └─────────────────┘

```

**특징:**

- 컴퓨팅과 스토리지 분리
- 독립적인 확장 가능
- Data Lake 통합 용이

### **BE vs CN 비교**

| 항목 | BE 모드 | CN 모드 |
| --- | --- | --- |
| 스토리지 | 로컬 디스크 | S3/MinIO |
| 확장성 | 수직적 | 수평적 (컴퓨팅/스토리지 독립) |
| 비용 | 고정 비용 | 사용량 기반 |
| 지연시간 | 낮음 | 상대적으로 높음 |
| Data Lake 통합 | 제한적 | 네이티브 지원 |

---

## **Production 환경 권장사항**

> CN 모드 권장 안내
> 
> 
> Production 환경에서 Data Lake(S3, MinIO, HDFS 등)를 함께 사용하신다면 **CN(Compute Node) 모드를 권장**합니다.
> 

### **CN 모드의 장점**

| 장점 | 설명 |
| --- | --- |
| **스토리지 분리** | 컴퓨팅과 스토리지가 분리되어 독립적인 확장 가능 |
| **비용 효율성** | 필요에 따라 컴퓨팅 리소스만 확장/축소 가능 |
| **Data Lake 통합** | S3, MinIO 등 오브젝트 스토리지와 네이티브 연동 |
| **탄력적 운영** | 워크로드에 따른 유연한 리소스 조절 |
| **데이터 내구성** | 오브젝트 스토리지의 높은 내구성 활용 |

### **BE 모드가 적합한 케이스**

- 로컬 디스크 기반의 고성능 OLAP이 필요한 경우
- 네트워크 지연이 민감한 실시간 분석
- 단순한 아키텍처 선호
- 소규모 데이터셋

### **Production 배포 시 고려사항**

1. **고가용성**: FE 3대 이상, BE/CN 3대 이상 구성
2. **스토리지**: Production S3 또는 MinIO 클러스터 구성
3. **모니터링**: Prometheus + Grafana 연동
4. **백업**: 정기적인 메타데이터 백업

---

## **트러블슈팅**

### **FE가 시작되지 않는 경우**

```bash
# 로그 확인
docker logs starrocks-fe

# 메타 디렉토리 권한 확인
docker exec starrocks-fe ls -la /opt/starrocks/fe/meta

```

### **BE/CN이 FE에 등록되지 않는 경우**

```bash
# StarRocks에서 BE/CN 상태 확인
mysql -h 127.0.0.1 -P 9030 -u root -e "SHOW BACKENDS;"
mysql -h 127.0.0.1 -P 9030 -u root -e "SHOW COMPUTE NODES;"

# 수동으로 BE 등록
mysql -h 127.0.0.1 -P 9030 -u root -e "ALTER SYSTEM ADD BACKEND 'starrocks-be:9050';"

# 수동으로 CN 등록
mysql -h 127.0.0.1 -P 9030 -u root -e "ALTER SYSTEM ADD COMPUTE NODE 'starrocks-cn:9050';"

```

### **MySQL 연결 오류**

```bash
# MySQL 컨테이너 상태 확인
docker logs mysql

# MySQL 네트워크 연결 테스트
docker exec starrocks-fe mysql -h mysql -P 3306 -u root -p'StarRocksDemo1!' -e "SELECT 1;"

```

### **MySQL 8.0 RSA Public Key 오류**

MySQL 8.0에서 다음 오류가 발생하는 경우:

```
RSA public key is not available client side (option serverRsaPublicKeyFile not set)
```

**해결 방법**: JDBC URI에 다음 옵션을 추가하세요:

```sql
"jdbc_uri" = "jdbc:mysql://mysql:3306?allowPublicKeyRetrieval=true&useSSL=false"
```

### **MinIO 연결 오류 (CN 모드)**

```bash
# MinIO 상태 확인
docker logs minio

# 버킷 확인
docker exec minio-init mc ls myminio/

# MinIO 헬스체크
curl http://127.0.0.1:9000/minio/health/live
```

### **일반적인 디버깅 명령어**

```bash
# 전체 컨테이너 상태
docker compose --profile be ps
docker compose --profile cn ps

# 네트워크 확인
docker network inspect starrocks_demo_starrocks-net

# 볼륨 확인
docker volume ls | grep starrocks
```

---

## **정리**

### **BE 모드 정리**

```bash
# 서비스 중지 및 삭제
docker compose --profile be down

# 볼륨까지 삭제 (데이터 포함)
docker compose --profile be down -v
```

### **CN 모드 정리**

```bash
# 서비스 중지 및 삭제
docker compose --profile cn down

# 볼륨까지 삭제 (데이터 포함)
docker compose --profile cn down -v
```

### **전체 정리**

```bash
# 모든 서비스 및 볼륨 삭제
docker compose --profile be --profile cn down -v

# 이미지까지 삭제
docker compose --profile be --profile cn down -v --rmi all
```

---

## **파일 구조**

```
starrocks_demo/
├── docker-compose.yml          # Docker Compose 설정
├── README.md                   # 이 문서
├── demo.sql                    # 원본 데모 SQL (참고용)
├── config/
│   ├── mysql/
│   │   └── my.cnf              # MySQL 설정 (binlog 활성화)
│   ├── fe/
│   │   └── fe.conf             # StarRocks FE 설정
│   ├── be/
│   │   └── be.conf             # StarRocks BE 설정
│   └── cn/
│       └── cn.conf             # StarRocks CN 설정
└── scripts/
    ├── mysql-init.sql          # MySQL 초기화 스크립트
    ├── starrocks-be-init.sql   # BE 모드 StarRocks 초기화
    └── starrocks-cn-init.sql   # CN 모드 StarRocks 초기화

```

---

## **참고 자료**

### **공식 문서**

- [StarRocks 공식 문서](https://docs.starrocks.io/)
- [StarRocks Docker 배포 (Shared-Nothing/BE 모드)](https://docs.starrocks.io/docs/quick_start/shared-nothing/)
- [StarRocks Docker 배포 (Shared-Data/CN 모드)](https://docs.starrocks.io/docs/quick_start/shared-data/)
- [StarRocks 공식 Demo docker-compose.yml](https://github.com/StarRocks/demo/blob/master/documentation-samples/quickstart/docker-compose.yml)

### **기능별 문서**

- [StarRocks External Catalog (JDBC)](https://docs.starrocks.io/docs/data_source/catalog/jdbc_catalog/)
- [StarRocks Primary Key 테이블](https://docs.starrocks.io/docs/table_design/table_types/primary_key_table/)
- [StarRocks Task 스케줄링](https://docs.starrocks.io/docs/loading/Etl_using_task/)

---

**문의사항이 있으시면 연락 주세요.**
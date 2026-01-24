MySQL에서 StarRocks로의 데이터 동기화(CDC) 데모 환경입니다-TASK를 활용한.
 Docker Compose를 사용하여 손쉽게 구축할 수 있습니다.

---

## **개요**

이 데모는 다음을 검증합니다:

- MySQL에서 StarRocks로의 데이터 동기화
- StarRocks External Catalog를 통한 MySQL 연결
- Primary Key 테이블을 활용한 CDC 구현
- 스케줄 Task를 통한 주기적 동기화

## **아키텍처 설명**

### **지원 모드**

| 모드 | 설명 | 적합한 사용 사례 |
| --- | --- | --- |
| **BE (Backend)** | 로컬 디스크 기반 스토리지 | 고성능 OLAP, 낮은 지연 |
| **CN (Compute Node)** | S3/MinIO 오브젝트 스토리지 | Data Lake 통합, 탄력적 확장 |

---

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


## **사전 요구사항**

### **소프트웨어 요구사항**

- Docker 20.10 이상
- Docker Compose v2.0 이상
- MySQL Client (MySQL/StarRocks 접속용)
- PostgreSQL Client - psql (RisingWave 사용 시)

### **하드웨어 최소 사양**

| 프로파일 | CPU | RAM | 디스크 | 비고 |
|----------|-----|-----|--------|------|
| BE 기본 | 2 cores | 8GB | 20GB | MySQL + StarRocks FE/BE |
| CN 기본 | 2 cores | 8GB | 20GB | MySQL + StarRocks FE/CN + MinIO |
| + Flink | +2 cores | +4GB | +5GB | JobManager + TaskManager |
| + RisingWave | +1 core | +2GB | +5GB | 단일 노드 |
| + Rill | +1 core | +1GB | +2GB | BI Dashboard + Nginx |

**권장 사양 (전체 기능 사용 시):**
- CPU: 4 cores 이상
- RAM: 16GB 이상
- 디스크: 50GB 이상 (샘플 데이터 포함)

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
| MySQL | 3306 | `mysql -h 127.0.0.1 -P 3306 -u root -p'starrocks_demo_pw1#'` |
| StarRocks (MySQL Protocol) | 9030 | `mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#'` |
| StarRocks Web UI | 8030 | [http://127.0.0.1:8030](http://127.0.0.1:8030/) |
| Flink Web UI (flink모드) | 8082 | [http://127.0.0.1:8082](http://127.0.0.1:8082/) |
| MinIO Console (CN모드) | 9001 | [http://127.0.0.1:9001](http://127.0.0.1:9001/) (admin / StarRocksDemo1!_minio) |

### **전체 포트 목록**

| 포트 | 서비스 | 프로토콜 | 프로파일 | 설명 |
|------|--------|----------|----------|------|
| 3306 | MySQL | TCP | 기본 | MySQL 데이터베이스 |
| 8030 | StarRocks FE | HTTP | 기본 | FE Web UI / Stream Load |
| 9020 | StarRocks FE | TCP | 기본 | FE Edit Log |
| 9030 | StarRocks FE | TCP | 기본 | FE MySQL Protocol |
| 8040 | StarRocks BE/CN | HTTP | 기본 | BE/CN Web UI |
| 9050 | StarRocks BE/CN | TCP | 기본 | BE/CN Heartbeat |
| 9060 | StarRocks BE/CN | TCP | 기본 | BE/CN BRPC |
| 9000 | MinIO | HTTP | cn | MinIO API |
| 9001 | MinIO | HTTP | cn | MinIO Console |
| 8082 | Flink JobManager | HTTP | flink | Flink Web UI |
| 4566 | RisingWave | TCP | risingwave | PostgreSQL Protocol |
| 5691 | RisingWave | HTTP | risingwave | RisingWave Dashboard |
| 9010 | Rill (via Nginx) | HTTP | rill | Rill BI Dashboard |

---

## **Flink CDC 모드 (실시간 동기화)**

Task 스케줄링 대신 Flink CDC를 사용한 실시간 binlog 기반 동기화도 지원합니다.

```bash
docker compose --profile be --profile flink up -d --build
```

자세한 사용법은 [docs/CDC_Flink.md](docs/CDC_Flink.md)를 참조하세요.

---

## **RisingWave CDC 모드 (스트리밍 데이터베이스)**

PostgreSQL 호환 스트리밍 데이터베이스인 RisingWave를 사용한 실시간 CDC도 지원합니다.

```bash
# BE 모드 + RisingWave
docker compose --profile be --profile risingwave up -d

# CN 모드 + RisingWave
docker compose --profile cn --profile risingwave up -d
```

### RisingWave 접속 정보

| 서비스 | 포트 | 접속 방법 |
|--------|------|----------|
| RisingWave SQL | 4566 | `psql -h 127.0.0.1 -p 4566 -U root -d dev` |
| RisingWave Dashboard | 5691 | http://localhost:5691 |

자세한 사용법은 [docs/CDC_RisingWave.md](docs/CDC_RisingWave.md)를 참조하세요.

---

## **Rill BI 대시보드 (데이터 시각화)**

StarRocks 데이터를 시각화하는 Rill BI 대시보드를 지원합니다.

```bash
# BE 모드 + Rill
docker compose --profile be --profile rill up -d

# CN 모드 + Rill
docker compose --profile cn --profile rill up -d
```

### Rill 접속 정보

| 서비스 | 포트 | 접속 방법 |
|--------|------|----------|
| Rill Dashboard | 9010 | http://localhost:9010 |

**특징:**
- YAML 기반 선언적 대시보드 구성
- NYC Yellow Taxi 샘플 데이터 포함
- 네트워크 격리 아키텍처 (Rill은 StarRocks만 접근 가능)

자세한 사용법은 [docs/Dashboard_Rill.md](docs/Dashboard_Rill.md)를 참조하세요.

---

## **데모 시나리오**

세 가지 방식의 MySQL → StarRocks 데이터 동기화를 지원합니다.

### **Task 스케줄링 방식 (기본)**

StarRocks의 External Catalog와 주기적 Task를 사용한 데이터 동기화입니다.

- External Catalog로 MySQL 직접 조회 (Federation Query)
- Primary Key 테이블로 UPSERT 동작 지원
- 설정된 주기(예: 5분)마다 변경 데이터 동기화

자세한 사용법은 [docs/Syncdata_MySQL.md](docs/Syncdata_MySQL.md)를 참조하세요.

### **Flink CDC 방식 (실시간)**

Apache Flink CDC를 사용한 실시간 binlog 기반 동기화입니다.

- 밀리초 단위 지연으로 실시간 동기화
- 스키마 변경 자동 전파 (CDC 3.0+)
- Flink 클러스터 필요

자세한 사용법은 [docs/CDC_Flink.md](docs/CDC_Flink.md)를 참조하세요.

### **RisingWave 방식 (스트리밍 DB)**

RisingWave 스트리밍 데이터베이스를 사용한 실시간 binlog 기반 동기화입니다.

- PostgreSQL 호환 SQL로 간편한 파이프라인 구성
- 밀리초 단위 지연으로 실시간 동기화
- 단일 노드로 경량 배포 가능
- Web Dashboard로 직관적인 모니터링

자세한 사용법은 [docs/CDC_RisingWave.md](docs/CDC_RisingWave.md)를 참조하세요.

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
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' -e "SHOW BACKENDS;"
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' -e "SHOW COMPUTE NODES;"

# 수동으로 BE 등록
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' -e "ALTER SYSTEM ADD BACKEND 'starrocks-be:9050';"

# 수동으로 CN 등록
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' -e "ALTER SYSTEM ADD COMPUTE NODE 'starrocks-cn:9050';"

```

### **MySQL 연결 오류**

```bash
# MySQL 컨테이너 상태 확인
docker logs mysql

# MySQL 네트워크 연결 테스트
docker exec starrocks-fe mysql -h mysql -P 3306 -u root -p'starrocks_demo_pw1#' -e "SELECT 1;"

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
├── CLAUDE.md                   # Claude Code 가이드
│
├── cdc/                        # CDC 파이프라인
│   ├── flink/                  # Flink CDC (flink 프로파일)
│   │   ├── Dockerfile
│   │   └── pipelines/
│   │       └── mysql-to-starrocks.yaml
│   └── risingwave/             # RisingWave CDC (risingwave 프로파일)
│       └── setup-pipeline.sql
│
├── bi/                         # BI 도구
│   └── rill-project/           # Rill BI 대시보드 (rill 프로파일)
│       ├── rill.yaml
│       ├── connectors/
│       ├── metrics/
│       └── dashboards/
│
├── config/                     # 서비스 설정 파일
│   ├── mysql/
│   ├── fe/
│   ├── be/
│   ├── cn/
│   └── nginx/
│
├── scripts/                    # 초기화 SQL 스크립트
│   ├── mysql-init.sql
│   ├── mysql-orders-init.sql
│   ├── starrocks-be-init.sql
│   ├── starrocks-cn-init.sql
│   ├── starrocks-rill-init.sql
│   └── starrocks-risingwave-init.sql
│
├── data/                       # 샘플 데이터
│   └── sample/
│       ├── taxi_zone_lookup.csv
│       └── yellow_tripdata_2024-01.parquet
│
└── docs/                       # 사용 가이드
    ├── img/
    ├── CDC_Flink.md
    ├── CDC_RisingWave.md
    ├── Dashboard_Rill.md
    └── Syncdata_MySQL.md

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
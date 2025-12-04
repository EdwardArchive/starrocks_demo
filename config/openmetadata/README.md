# OpenMetadata Configuration

## 기본 자격증명

- **URL**: http://localhost:8585
- **Username**: admin
- **Password**: admin

## MySQL 데이터베이스 연결

OpenMetadata UI에서 MySQL을 데이터 소스로 추가하려면:

1. Settings > Services > Databases로 이동
2. "Add New Service" 클릭
3. "MySQL" 선택
4. 연결 정보 입력:
   - **Name**: mysql_demo
   - **Host**: mysql
   - **Port**: 3306
   - **Username**: root
   - **Password**: StarRocksDemo1!
   - **Database**: demo_db

## StarRocks 데이터베이스 연결

StarRocks는 MySQL 프로토콜을 사용하므로 MySQL 커넥터로 연결합니다:

1. Settings > Services > Databases로 이동
2. "Add New Service" 클릭
3. "MySQL" 선택
4. 연결 정보 입력:
   - **Name**: starrocks_analytics
   - **Host**: starrocks-fe
   - **Port**: 9030
   - **Username**: root
   - **Password**: (빈칸)
   - **Database**: analytics_db

## 메타데이터 수집 (Ingestion)

서비스 추가 후:

1. 해당 서비스 선택
2. "Ingestion" 탭 클릭
3. "Add Metadata Ingestion" 클릭
4. 기본 설정으로 저장
5. "Run" 클릭하여 메타데이터 수집 시작

## 트러블슈팅

### 서비스가 시작되지 않는 경우
```bash
# 로그 확인
docker logs openmetadata-server

# 의존성 서비스 확인
docker logs openmetadata-postgres
docker logs openmetadata-elasticsearch
```

### Elasticsearch 메모리 부족
ES_JAVA_OPTS 설정을 조정하세요 (docker-compose.yml)

### 초기화가 오래 걸리는 경우
OpenMetadata는 첫 시작 시 2-3분 정도 소요될 수 있습니다.
healthcheck의 start_period가 60초로 설정되어 있습니다.

## 참고 링크

- [OpenMetadata Documentation](https://docs.open-metadata.org/)
- [OpenMetadata MySQL Connector](https://docs.open-metadata.org/connectors/database/mysql)

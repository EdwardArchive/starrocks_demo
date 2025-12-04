# Flink CDC Connector JARs

## 자동 포함

Flink CDC 및 StarRocks 커넥터 JAR 파일은 **Docker 이미지 빌드 시 자동으로 다운로드**됩니다.

`config/flink/Dockerfile`에서 다음 JAR 파일들을 다운로드합니다:
- `flink-sql-connector-mysql-cdc-3.2.1.jar`
- `flink-connector-starrocks-1.2.10_flink-1.20.jar`
- `mysql-connector-java-8.0.28.jar`

## 사용 방법

별도의 JAR 다운로드 없이 바로 실행 가능합니다:

```bash
docker compose --profile be --profile flink up -d
```

첫 실행 시 이미지 빌드에 시간이 소요될 수 있습니다.

## 수동 다운로드 (선택사항)

로컬에서 JAR 파일을 확인하거나 테스트하려면:

```bash
# Linux/Mac
curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.2.1/flink-sql-connector-mysql-cdc-3.2.1.jar
curl -O https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.10_flink-1.20/flink-connector-starrocks-1.2.10_flink-1.20.jar
curl -O https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar
```

## 참고 링크

- [Flink CDC Documentation](https://nightlies.apache.org/flink/flink-cdc-docs-release-3.2/)
- [StarRocks Flink Connector](https://docs.starrocks.io/docs/loading/Flink-connector-starrocks/)
- [Maven Repository](https://repo1.maven.org/maven2/)

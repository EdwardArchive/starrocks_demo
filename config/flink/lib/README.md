# Flink CDC Connector JARs

이 디렉토리에 Flink CDC 및 StarRocks 커넥터 JAR 파일을 다운로드하세요.

## 필요한 JAR 파일

### 1. Flink CDC Connector (MySQL)
```bash
# Flink SQL Connector MySQL CDC 3.2.1
curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.2.1/flink-sql-connector-mysql-cdc-3.2.1.jar
```

### 2. StarRocks Connector for Flink
```bash
# StarRocks Connector for Flink 1.20
curl -O https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.10_flink-1.20/flink-connector-starrocks-1.2.10_flink-1.20.jar
```

### 3. MySQL JDBC Driver
```bash
# MySQL Connector Java 8.0.28
curl -O https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar
```

## 자동 다운로드 스크립트

Linux/Mac:
```bash
cd config/flink/lib
curl -O https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.2.1/flink-sql-connector-mysql-cdc-3.2.1.jar
curl -O https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.10_flink-1.20/flink-connector-starrocks-1.2.10_flink-1.20.jar
curl -O https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar
```

Windows (PowerShell):
```powershell
cd config\flink\lib
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.2.1/flink-sql-connector-mysql-cdc-3.2.1.jar" -OutFile "flink-sql-connector-mysql-cdc-3.2.1.jar"
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.10_flink-1.20/flink-connector-starrocks-1.2.10_flink-1.20.jar" -OutFile "flink-connector-starrocks-1.2.10_flink-1.20.jar"
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar" -OutFile "mysql-connector-java-8.0.28.jar"
```

## 다운로드 후 디렉토리 구조

```
config/flink/lib/
├── README.md (이 파일)
├── flink-sql-connector-mysql-cdc-3.2.1.jar
├── flink-connector-starrocks-1.2.10_flink-1.20.jar
└── mysql-connector-java-8.0.28.jar
```

## 참고 링크

- [Flink CDC Documentation](https://nightlies.apache.org/flink/flink-cdc-docs-release-3.2/)
- [StarRocks Flink Connector](https://docs.starrocks.io/docs/loading/Flink-connector-starrocks/)
- [Maven Repository](https://repo1.maven.org/maven2/)

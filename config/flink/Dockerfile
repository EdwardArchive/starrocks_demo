FROM flink:1.20-java11

# Download Flink CDC and StarRocks connector JARs
RUN mkdir -p /opt/flink/lib && \
    curl -fSL -o /opt/flink/lib/flink-sql-connector-mysql-cdc-3.2.1.jar \
        https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.2.1/flink-sql-connector-mysql-cdc-3.2.1.jar && \
    curl -fSL -o /opt/flink/lib/flink-connector-starrocks-1.2.10_flink-1.20.jar \
        https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.10_flink-1.20/flink-connector-starrocks-1.2.10_flink-1.20.jar && \
    curl -fSL -o /opt/flink/lib/mysql-connector-java-8.0.28.jar \
        https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar

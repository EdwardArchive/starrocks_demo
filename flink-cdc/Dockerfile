FROM flink:1.18

# Flink CDC 다운로드 및 설치
ARG FLINK_CDC_VERSION=3.2.0
ARG MYSQL_CONNECTOR_VERSION=8.0.27

RUN mkdir -p /opt/flink-cdc/lib

# Flink CDC CLI 다운로드 (Apache Archive에서)
RUN wget -q https://archive.apache.org/dist/flink/flink-cdc-${FLINK_CDC_VERSION}/flink-cdc-${FLINK_CDC_VERSION}-bin.tar.gz \
    && tar -xzf flink-cdc-${FLINK_CDC_VERSION}-bin.tar.gz -C /opt/flink-cdc --strip-components=1 \
    && rm flink-cdc-${FLINK_CDC_VERSION}-bin.tar.gz

# Pipeline Connectors (Maven Central에서)
RUN wget -q -P /opt/flink-cdc/lib \
    https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-mysql/${FLINK_CDC_VERSION}/flink-cdc-pipeline-connector-mysql-${FLINK_CDC_VERSION}.jar

RUN wget -q -P /opt/flink-cdc/lib \
    https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-starrocks/${FLINK_CDC_VERSION}/flink-cdc-pipeline-connector-starrocks-${FLINK_CDC_VERSION}.jar

# MySQL JDBC Driver (GPL 라이선스로 별도 다운로드 필요)
RUN wget -q -P /opt/flink/lib \
    https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar

# 환경변수 설정
ENV FLINK_CDC_HOME=/opt/flink-cdc
ENV PATH="${FLINK_CDC_HOME}/bin:${PATH}"

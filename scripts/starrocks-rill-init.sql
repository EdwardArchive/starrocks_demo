-- StarRocks Rill 데모용 초기화 스크립트
-- NYC Yellow Taxi Trip Data

-- 1. 분석용 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS analytics_db;
USE analytics_db;

-- 2. Taxi Zone Lookup 테이블
CREATE TABLE IF NOT EXISTS taxi_zone_lookup (
    LocationID INT,
    Borough VARCHAR(50),
    Zone VARCHAR(100),
    service_zone VARCHAR(50)
)
PRIMARY KEY (LocationID)
DISTRIBUTED BY HASH(LocationID) BUCKETS 1
PROPERTIES (
    "replication_num" = "1"
);

-- 3. Yellow Taxi Trips 테이블
CREATE TABLE IF NOT EXISTS yellow_taxi_trips (
    VendorID INT,
    tpep_pickup_datetime DATETIME,
    tpep_dropoff_datetime DATETIME,
    passenger_count DOUBLE,
    trip_distance DOUBLE,
    RatecodeID DOUBLE,
    store_and_fwd_flag VARCHAR(10),
    PULocationID INT,
    DOLocationID INT,
    payment_type BIGINT,
    fare_amount DOUBLE,
    extra DOUBLE,
    mta_tax DOUBLE,
    tip_amount DOUBLE,
    tolls_amount DOUBLE,
    improvement_surcharge DOUBLE,
    total_amount DOUBLE,
    congestion_surcharge DOUBLE,
    Airport_fee DOUBLE
)
DUPLICATE KEY (VendorID, tpep_pickup_datetime)
DISTRIBUTED BY HASH(VendorID) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);

-- 4. 데이터 확인
SELECT COUNT(*) as total_zones FROM taxi_zone_lookup;
SELECT COUNT(*) as total_trips FROM yellow_taxi_trips;


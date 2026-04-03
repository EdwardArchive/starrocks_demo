# StarRocks RBAC (역할 기반 접근 제어) 데모

## 개요

이 데모는 StarRocks의 RBAC(Role-Based Access Control) 기능을 실습할 수 있는 환경을 제공합니다.
4단계 역할 계층 구조, 12개 역할, 10명의 사용자를 통해 엔터프라이즈 환경의 접근 제어를 체험할 수 있습니다.

## RBAC 핵심 개념

### 역할 (Role)
권한의 묶음입니다. 사용자에게 직접 권한을 부여하는 대신, 역할에 권한을 부여하고 사용자에게 역할을 할당합니다.

### 역할 상속 (Role Inheritance)
역할에 다른 역할을 부여할 수 있습니다. `GRANT role_a TO ROLE role_b`를 실행하면, `role_b`를 가진 사용자는 `role_a`의 권한도 자동으로 획득합니다.

### 기본 역할 (Default Role)
사용자가 로그인했을 때 자동으로 활성화되는 역할입니다. 부여받은 역할 중 일부만 기본 역할로 설정하면, 나머지는 `SET ROLE` 명령어로 수동 전환해야 합니다. 이를 통해 **최소 권한 원칙**을 구현할 수 있습니다.

### 내장 역할 (Built-in Roles)
StarRocks가 기본 제공하는 역할:
- `db_admin` — 모든 데이터베이스/테이블/뷰/함수 관리
- `user_admin` — 사용자/역할 생성 및 권한 부여
- `cluster_admin` — 노드, 플러그인, 리소스 그룹 관리

---

## 역할 계층 다이어그램 (4-Tier, 12개 역할)

```
┌─────────────────────────────────────────────────────────┐
│ Tier 4: Super Admin                                     │
│   platform_admin ── db_admin + user_admin + cluster_admin│
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────┐
│ Tier 3: Lead / Manager                                  │
│   analytics_lead ──── senior_analyst + base_writer      │
│   engineering_lead ── data_engineering_team              │
│                       + task_operator + backup_operator  │
│   security_officer ── audit_reader + user_admin         │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────┐
│ Tier 2: Department / Function                           │
│   analytics_team ──── base_reader + catalog_user        │
│   senior_analyst ──── analytics_team + mv_creator       │
│   data_engineering_team ── base_writer + base_ddl       │
│                            + catalog_user               │
│   report_viewer ───── base_reader                       │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────┐
│ Tier 1: Base (원자적 권한 단위)                          │
│   base_reader ───── SELECT on analytics_db.*            │
│   base_writer ───── SELECT + INSERT + DELETE            │
│   base_ddl ──────── CREATE TABLE, ALTER, DROP           │
│   catalog_user ──── USAGE on mysql_catalog + SELECT     │
│   mv_creator ────── CREATE MATERIALIZED VIEW            │
│   task_operator ─── INSERT (Task 실행용)                │
│   backup_operator ─ REPOSITORY on SYSTEM                │
│   audit_reader ──── SELECT on _statistics_.*            │
└─────────────────────────────────────────────────────────┘
```

---

## 사용자 목록 (10명)

| 사용자 | 소속 | 역할 | 기본 역할 | 비밀번호 |
|--------|------|------|----------|---------|
| `diana_admin` | 경영 | `platform_admin` | ALL | `demo_pw1#` |
| `frank_secops` | 경영 | `security_officer` | ALL | `demo_pw1#` |
| `grace_cto` | 경영 | `platform_admin` + `analytics_lead` | `analytics_lead` | `demo_pw1#` |
| `harry_lead` | 엔지니어링 | `engineering_lead` | ALL | `demo_pw1#` |
| `charlie_engineer` | 엔지니어링 | `data_engineering_team` | ALL | `demo_pw1#` |
| `ivan_junior` | 엔지니어링 | `base_writer` + `catalog_user` | `base_writer` | `demo_pw1#` |
| `jenny_lead` | 분석 | `analytics_lead` | ALL | `demo_pw1#` |
| `alice_analyst` | 분석 | `analytics_team` | ALL | `demo_pw1#` |
| `bob_senior` | 분석 | `senior_analyst` | `analytics_team` | `demo_pw1#` |
| `kate_intern` | 외부 | `report_viewer` | ALL | `demo_pw1#` |

---

## 권한 매트릭스

| 사용자 | SELECT | Catalog | INSERT | DDL | MV | Admin |
|--------|:------:|:-------:|:------:|:---:|:--:|:-----:|
| kate_intern | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| alice_analyst | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| bob_senior | ✓ | ✓ | ✗ | ✗ | △ | ✗ |
| ivan_junior | ✓ | △ | ✓ | ✗ | ✗ | ✗ |
| charlie_engineer | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| jenny_lead | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |
| harry_lead | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| frank_secops | ✗ | ✗ | ✗ | ✗ | ✗ | △ |
| grace_cto | ✓ | ✓ | ✓ | ✗ | ✓ | △ |
| diana_admin | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

> ✓ = 허용 / ✗ = 거부 / △ = SET ROLE 전환 필요

---

## 데모 실행 방법

### 1. 환경 시작

```bash
# BE 모드
docker compose --profile be up -d

# CN 모드
docker compose --profile cn up -d
```

### 2. 초기 데이터 설정 (analytics_db 생성)

```bash
# BE 모드
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' < scripts/starrocks-be-init.sql

# CN 모드
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' < scripts/starrocks-cn-init.sql
```

### 3. RBAC 초기화

`starrocks-rbac-init-be` (또는 `starrocks-rbac-init-cn`) 서비스가 자동으로 실행됩니다.
수동으로 실행하려면:

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p'starrocks_demo_pw1#' < scripts/starrocks-rbac-init.sql
```

### 4. 권한 검증 스크립트 실행

```bash
bash scripts/starrocks-rbac-verify.sh
```

---

## 체험 시나리오

### 시나리오 1: 기본 역할(Default Role) 전환 — bob_senior

`bob_senior`는 `senior_analyst` 역할을 보유하지만, 기본 역할은 `analytics_team`만 활성화됩니다.

```sql
-- bob_senior로 접속
mysql -h 127.0.0.1 -P 9030 -u bob_senior -p'demo_pw1#'

-- 현재 활성 역할 확인
SELECT CURRENT_ROLE();

-- MV 생성 시도 → 실패 (기본 역할에는 mv_creator 없음)
CREATE MATERIALIZED VIEW analytics_db.mv_test
AS SELECT category, COUNT(*) AS cnt
FROM analytics_db.products_sync GROUP BY category;

-- 역할 전환
SET ROLE senior_analyst;

-- MV 생성 시도 → 성공
CREATE MATERIALIZED VIEW analytics_db.mv_test
AS SELECT category, COUNT(*) AS cnt
FROM analytics_db.products_sync GROUP BY category;

-- 원래 역할로 복귀
SET ROLE analytics_team;
```

### 시나리오 2: 다중 역할 사용자 — grace_cto

`grace_cto`는 `platform_admin` + `analytics_lead` 두 역할을 보유하지만, 기본 역할은 `analytics_lead`만 활성화됩니다.

```sql
-- grace_cto로 접속
mysql -h 127.0.0.1 -P 9030 -u grace_cto -p'demo_pw1#'

-- 기본 역할(analytics_lead)로 분석 작업
SELECT category, AVG(price) FROM analytics_db.products_sync GROUP BY category;

-- 관리 작업 시도 → 실패
CREATE USER test_user IDENTIFIED BY 'test';

-- 모든 역할 활성화
SET ROLE ALL;

-- 관리 작업 시도 → 성공
CREATE USER IF NOT EXISTS test_user IDENTIFIED BY 'test';
DROP USER IF EXISTS test_user;
```

### 시나리오 3: 역할 상속 체인 — harry_lead

`harry_lead`의 역할 상속 경로:
```
harry_lead
  └─ engineering_lead
       ├─ data_engineering_team
       │    ├─ base_writer (SELECT + INSERT + DELETE)
       │    ├─ base_ddl (CREATE TABLE, ALTER, DROP)
       │    └─ catalog_user (mysql_catalog USAGE + SELECT)
       ├─ task_operator (INSERT for Task)
       └─ backup_operator (REPOSITORY)
```

```sql
-- harry_lead로 접속
mysql -h 127.0.0.1 -P 9030 -u harry_lead -p'demo_pw1#'

-- 상속받은 모든 권한 확인
SHOW GRANTS;

-- 3단계 상속으로 획득한 권한들 테스트
SELECT * FROM mysql_catalog.demo_db.products LIMIT 5;  -- catalog_user 상속
CREATE TABLE analytics_db.test_tbl (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1
PROPERTIES ('replication_num'='1');  -- base_ddl 상속
DROP TABLE analytics_db.test_tbl;
```

### 시나리오 4: 권한 거부 확인

```sql
-- kate_intern: INSERT 시도 → Access Denied
mysql -h 127.0.0.1 -P 9030 -u kate_intern -p'demo_pw1#' -e \
  "INSERT INTO analytics_db.products_sync VALUES (99999,'test','test',1.0,1,NOW(),NOW());"

-- alice_analyst: DDL 시도 → Access Denied
mysql -h 127.0.0.1 -P 9030 -u alice_analyst -p'demo_pw1#' -e \
  "CREATE TABLE analytics_db.test (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1;"

-- frank_secops: 비즈니스 데이터 접근 → Access Denied (감사/사용자관리만 가능)
mysql -h 127.0.0.1 -P 9030 -u frank_secops -p'demo_pw1#' -e \
  "SELECT * FROM analytics_db.products_sync LIMIT 1;"
```

---

## 주요 명령어 레퍼런스

```sql
-- 역할 관리
CREATE ROLE role_name;
DROP ROLE role_name;
SHOW ROLES;

-- 권한 부여
GRANT SELECT ON ALL TABLES IN DATABASE db_name TO ROLE role_name;
GRANT USAGE ON CATALOG catalog_name TO ROLE role_name;
GRANT role_a TO ROLE role_b;  -- 역할 상속
REVOKE role_a FROM ROLE role_b;

-- 사용자 관리
CREATE USER user_name IDENTIFIED BY 'password';
GRANT role_name TO USER user_name;
SET DEFAULT ROLE ALL TO user_name;
SET DEFAULT ROLE role_name TO user_name;

-- 세션 내 역할 전환
SET ROLE role_name;          -- 특정 역할만 활성화
SET ROLE ALL;                -- 부여받은 모든 역할 활성화
SELECT CURRENT_ROLE();       -- 현재 활성 역할 확인

-- 권한 확인
SHOW GRANTS;                          -- 현재 사용자
SHOW GRANTS FOR user_name;            -- 특정 사용자
SHOW GRANTS FOR ROLE role_name;       -- 특정 역할
```

---

## 참고사항

- `GRANT ON ALL TABLES`는 실행 시점에 존재하는 테이블에만 적용됩니다. 이후 생성된 테이블에는 다시 GRANT가 필요합니다.
- StarRocks에는 `SUBMIT TASK` 전용 권한이 없습니다. Task는 내부적으로 INSERT를 수행하므로, 대상 테이블에 INSERT 권한이 있으면 Task를 실행할 수 있습니다.
- `SET ROLE`은 세션 단위입니다. 새 세션에서는 항상 기본 역할(Default Role)로 돌아갑니다.

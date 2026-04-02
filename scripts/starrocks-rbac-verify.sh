#!/bin/bash
# ============================================================
# StarRocks RBAC 권한 검증 데모 스크립트
# 각 사용자로 접속하여 허용/거부되는 작업을 확인합니다.
# ============================================================

SR_HOST="${SR_HOST:-127.0.0.1}"
SR_PORT="${SR_PORT:-9030}"
PW="demo_pw1#"

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 구분선
LINE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_query() {
    local user=$1
    local query=$2
    local desc=$3
    local expect_success=$4  # "yes" or "no"

    result=$(mysql -h "$SR_HOST" -P "$SR_PORT" -u "$user" -p"$PW" -e "$query" 2>&1)
    exit_code=$?

    if [ "$expect_success" = "yes" ]; then
        if [ $exit_code -eq 0 ]; then
            echo -e "  ${GREEN}✓ PASS${NC} $desc"
        else
            echo -e "  ${RED}✗ UNEXPECTED FAIL${NC} $desc"
            echo -e "    ${RED}→ $result${NC}"
        fi
    else
        if [ $exit_code -ne 0 ]; then
            echo -e "  ${GREEN}✓ DENIED (expected)${NC} $desc"
        else
            echo -e "  ${RED}✗ UNEXPECTED PASS${NC} $desc (should have been denied)"
        fi
    fi
}

run_query_with_output() {
    local user=$1
    local query=$2
    local desc=$3

    echo -e "  ${CYAN}→${NC} $desc"
    mysql -h "$SR_HOST" -P "$SR_PORT" -u "$user" -p"$PW" -e "$query" 2>&1 | sed 's/^/    /'
    echo ""
}

echo -e "${BOLD}${LINE}${NC}"
echo -e "${BOLD} StarRocks RBAC 권한 검증 데모${NC}"
echo -e "${BOLD}${LINE}${NC}"
echo ""

# ===========================================================
# 1. kate_intern (인턴 - report_viewer)
# ===========================================================
echo -e "${YELLOW}[1/10] kate_intern (인턴 - report_viewer)${NC}"
echo -e "  역할: report_viewer → base_reader"
echo ""
run_query "kate_intern" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db" "yes"
run_query "kate_intern" "INSERT INTO analytics_db.products_sync (product_id, product_name, category, price, stock_quantity, last_updated) VALUES (99999,'test','test',1.0,1,NOW());" \
    "INSERT on analytics_db (should be denied)" "no"
run_query "kate_intern" "SELECT * FROM mysql_catalog.demo_db.products LIMIT 1;" \
    "SELECT on mysql_catalog (should be denied)" "no"
run_query "kate_intern" "CREATE TABLE analytics_db.test_table (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1;" \
    "CREATE TABLE (should be denied)" "no"
echo ""

# ===========================================================
# 2. alice_analyst (분석가 - analytics_team)
# ===========================================================
echo -e "${YELLOW}[2/10] alice_analyst (분석가 - analytics_team)${NC}"
echo -e "  역할: analytics_team → base_reader + catalog_user"
echo ""
run_query "alice_analyst" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db" "yes"
run_query "alice_analyst" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog" "yes"
run_query "alice_analyst" "INSERT INTO analytics_db.products_sync (product_id, product_name, category, price, stock_quantity, last_updated) VALUES (99999,'test','test',1.0,1,NOW());" \
    "INSERT on analytics_db (should be denied)" "no"
run_query "alice_analyst" "CREATE TABLE analytics_db.test_table (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1;" \
    "CREATE TABLE (should be denied)" "no"
echo ""

# ===========================================================
# 3. bob_senior (시니어 분석가 - Default Role 전환 데모)
# ===========================================================
echo -e "${YELLOW}[3/10] bob_senior (시니어 분석가 - DEFAULT ROLE 전환 데모)${NC}"
echo -e "  부여 역할: senior_analyst (→ analytics_team + mv_creator)"
echo -e "  기본 역할: analytics_team만 활성화"
echo ""

# 기본 역할 상태에서 테스트
run_query "bob_senior" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db (기본 역할)" "yes"
run_query "bob_senior" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog (기본 역할)" "yes"

echo ""
echo -e "  ${CYAN}── 현재 기본 역할(analytics_team)에서 MV 생성 시도 ──${NC}"
run_query "bob_senior" "CREATE MATERIALIZED VIEW analytics_db.mv_test REFRESH ASYNC AS SELECT category, COUNT(*) AS cnt FROM analytics_db.products_sync GROUP BY category;" \
    "CREATE MV (기본 역할 - should be denied)" "no"

echo ""
echo -e "  ${CYAN}── SET ROLE senior_analyst 로 역할 전환 후 MV 생성 시도 ──${NC}"
echo -e "  ${CYAN}  (참고: SET ROLE은 세션 단위이므로, 단일 쿼리에서 시연)${NC}"
run_query "bob_senior" "SET ROLE senior_analyst; CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_db.mv_category_stats REFRESH ASYNC AS SELECT category, COUNT(*) AS cnt FROM analytics_db.products_sync GROUP BY category;" \
    "CREATE MV (senior_analyst 역할 전환 후)" "yes"

# 정리
mysql -h "$SR_HOST" -P "$SR_PORT" -u root -p'starrocks_demo_pw1#' -e "DROP MATERIALIZED VIEW IF EXISTS analytics_db.mv_category_stats;" 2>/dev/null
echo ""

# ===========================================================
# 4. ivan_junior (주니어 엔지니어 - base_writer + catalog_user)
# ===========================================================
echo -e "${YELLOW}[4/10] ivan_junior (주니어 엔지니어 - base_writer)${NC}"
echo -e "  부여 역할: base_writer + catalog_user"
echo -e "  기본 역할: base_writer만 활성화"
echo ""
run_query "ivan_junior" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db" "yes"
run_query "ivan_junior" "SELECT * FROM mysql_catalog.demo_db.products LIMIT 1;" \
    "SELECT on mysql_catalog (기본 역할 - should be denied)" "no"

echo ""
echo -e "  ${CYAN}── SET ROLE ALL 로 catalog_user 포함 전체 역할 활성화 ──${NC}"
run_query "ivan_junior" "SET ROLE ALL; SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog (SET ROLE ALL 후)" "yes"

run_query "ivan_junior" "CREATE TABLE analytics_db.test_table (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1;" \
    "CREATE TABLE (should be denied - DDL 권한 없음)" "no"
echo ""

# ===========================================================
# 5. charlie_engineer (시니어 엔지니어 - data_engineering_team)
# ===========================================================
echo -e "${YELLOW}[5/10] charlie_engineer (시니어 엔지니어 - data_engineering_team)${NC}"
echo -e "  역할: data_engineering_team → base_writer + base_ddl + catalog_user"
echo ""
run_query "charlie_engineer" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db" "yes"
run_query "charlie_engineer" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog" "yes"
run_query "charlie_engineer" "CREATE TABLE IF NOT EXISTS analytics_db.rbac_test_table (id INT, name VARCHAR(50)) PRIMARY KEY (id) DISTRIBUTED BY HASH(id) BUCKETS 1 PROPERTIES ('replication_num'='1');" \
    "CREATE TABLE on analytics_db" "yes"
run_query "charlie_engineer" "INSERT INTO analytics_db.rbac_test_table VALUES (1, 'test');" \
    "INSERT on analytics_db" "yes"
run_query "charlie_engineer" "DROP TABLE IF EXISTS analytics_db.rbac_test_table;" \
    "DROP TABLE on analytics_db" "yes"
run_query "charlie_engineer" "CREATE USER test_user_fail IDENTIFIED BY 'test';" \
    "CREATE USER (should be denied - 사용자 관리 권한 없음)" "no"
echo ""

# ===========================================================
# 6. harry_lead (엔지니어링 리드 - engineering_lead)
# ===========================================================
echo -e "${YELLOW}[6/10] harry_lead (엔지니어링 리드 - engineering_lead)${NC}"
echo -e "  역할: engineering_lead → data_engineering_team + task_operator + backup_operator"
echo -e "  3단계 상속: engineering_lead → data_engineering_team → base_writer + base_ddl + catalog_user"
echo ""
run_query "harry_lead" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db (상속)" "yes"
run_query "harry_lead" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog (상속)" "yes"
run_query "harry_lead" "CREATE TABLE IF NOT EXISTS analytics_db.rbac_test_table (id INT, name VARCHAR(50)) PRIMARY KEY (id) DISTRIBUTED BY HASH(id) BUCKETS 1 PROPERTIES ('replication_num'='1');" \
    "CREATE TABLE (상속)" "yes"
run_query "harry_lead" "INSERT INTO analytics_db.rbac_test_table VALUES (1, 'lead_test');" \
    "INSERT on analytics_db (task_operator)" "yes"
run_query "harry_lead" "DROP TABLE IF EXISTS analytics_db.rbac_test_table;" \
    "DROP TABLE (상속)" "yes"
run_query "harry_lead" "CREATE USER test_user_fail IDENTIFIED BY 'test';" \
    "CREATE USER (should be denied)" "no"
echo ""

# ===========================================================
# 7. jenny_lead (분석팀 리드 - analytics_lead)
# ===========================================================
echo -e "${YELLOW}[7/10] jenny_lead (분석팀 리드 - analytics_lead)${NC}"
echo -e "  역할: analytics_lead → senior_analyst + base_writer"
echo ""
run_query "jenny_lead" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db" "yes"
run_query "jenny_lead" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog" "yes"
run_query "jenny_lead" "CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_db.mv_jenny_test REFRESH ASYNC AS SELECT category, COUNT(*) AS cnt FROM analytics_db.products_sync GROUP BY category;" \
    "CREATE MV (mv_creator 상속)" "yes"
mysql -h "$SR_HOST" -P "$SR_PORT" -u root -p'starrocks_demo_pw1#' -e "DROP MATERIALIZED VIEW IF EXISTS analytics_db.mv_jenny_test;" 2>/dev/null
run_query "jenny_lead" "CREATE TABLE analytics_db.test_table (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1;" \
    "CREATE TABLE (should be denied - DDL 권한 없음)" "no"
echo ""

# ===========================================================
# 8. frank_secops (보안 담당자 - security_officer)
# ===========================================================
echo -e "${YELLOW}[8/10] frank_secops (보안 담당자 - security_officer)${NC}"
echo -e "  역할: security_officer → audit_reader + user_admin"
echo ""
run_query "frank_secops" "SHOW GRANTS FOR alice_analyst;" \
    "SHOW GRANTS (user_admin 권한)" "yes"
run_query "frank_secops" "SELECT * FROM analytics_db.products_sync LIMIT 1;" \
    "SELECT on analytics_db (should be denied - 비즈니스 데이터 접근 불가)" "no"
run_query "frank_secops" "SELECT * FROM mysql_catalog.demo_db.products LIMIT 1;" \
    "SELECT on mysql_catalog (should be denied)" "no"
echo ""

# ===========================================================
# 9. grace_cto (CTO - 다중 역할 + Default Role 전환 데모)
# ===========================================================
echo -e "${YELLOW}[9/10] grace_cto (CTO - 다중 역할 데모)${NC}"
echo -e "  부여 역할: platform_admin + analytics_lead"
echo -e "  기본 역할: analytics_lead만 활성화 (최소 권한 원칙)"
echo ""

# 기본 역할(analytics_lead)로 분석 작업
run_query "grace_cto" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db (기본: analytics_lead)" "yes"
run_query "grace_cto" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog (기본: analytics_lead)" "yes"

# 기본 역할에서 관리 작업 시도 → 거부
run_query "grace_cto" "CREATE USER test_cto_fail IDENTIFIED BY 'test';" \
    "CREATE USER (기본 역할 - should be denied)" "no"

echo ""
echo -e "  ${CYAN}── SET ROLE ALL: 모든 역할 활성화 (관리 모드 전환) ──${NC}"
run_query "grace_cto" "SET ROLE ALL; CREATE USER IF NOT EXISTS test_cto_temp IDENTIFIED BY 'temp123';" \
    "CREATE USER (SET ROLE ALL 후 - platform_admin 활성화)" "yes"

# 정리
mysql -h "$SR_HOST" -P "$SR_PORT" -u root -p'starrocks_demo_pw1#' -e "DROP USER IF EXISTS test_cto_temp;" 2>/dev/null
echo ""

# ===========================================================
# 10. diana_admin (플랫폼 관리자 - platform_admin)
# ===========================================================
echo -e "${YELLOW}[10/10] diana_admin (플랫폼 관리자 - platform_admin)${NC}"
echo -e "  역할: platform_admin → db_admin + user_admin + cluster_admin"
echo ""
run_query "diana_admin" "SELECT COUNT(*) AS cnt FROM analytics_db.products_sync;" \
    "SELECT on analytics_db" "yes"
run_query "diana_admin" "SELECT COUNT(*) AS cnt FROM mysql_catalog.demo_db.products;" \
    "SELECT on mysql_catalog" "yes"
run_query "diana_admin" "CREATE TABLE IF NOT EXISTS analytics_db.rbac_admin_test (id INT) DISTRIBUTED BY HASH(id) BUCKETS 1 PROPERTIES ('replication_num'='1');" \
    "CREATE TABLE" "yes"
run_query "diana_admin" "DROP TABLE IF EXISTS analytics_db.rbac_admin_test;" \
    "DROP TABLE" "yes"
run_query "diana_admin" "SHOW GRANTS FOR kate_intern;" \
    "SHOW GRANTS (user_admin)" "yes"
run_query "diana_admin" "SHOW BACKENDS;" \
    "SHOW BACKENDS (cluster_admin)" "yes"
echo ""

# ===========================================================
# 요약
# ===========================================================
echo -e "${BOLD}${LINE}${NC}"
echo -e "${BOLD} 권한 매트릭스 요약${NC}"
echo -e "${BOLD}${LINE}${NC}"
echo ""
echo -e "  사용자              │ SELECT │ Catalog │ INSERT │ DDL │ MV │ Admin"
echo -e "  ────────────────────┼────────┼─────────┼────────┼─────┼────┼──────"
echo -e "  kate_intern         │  ${GREEN}✓${NC}     │  ${RED}✗${NC}      │  ${RED}✗${NC}     │ ${RED}✗${NC}   │ ${RED}✗${NC}  │ ${RED}✗${NC}"
echo -e "  alice_analyst       │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${RED}✗${NC}     │ ${RED}✗${NC}   │ ${RED}✗${NC}  │ ${RED}✗${NC}"
echo -e "  bob_senior          │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${RED}✗${NC}     │ ${RED}✗${NC}   │ ${YELLOW}△${NC}  │ ${RED}✗${NC}"
echo -e "  ivan_junior         │  ${GREEN}✓${NC}     │  ${YELLOW}△${NC}      │  ${GREEN}✓${NC}     │ ${RED}✗${NC}   │ ${RED}✗${NC}  │ ${RED}✗${NC}"
echo -e "  charlie_engineer    │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${GREEN}✓${NC}     │ ${GREEN}✓${NC}   │ ${RED}✗${NC}  │ ${RED}✗${NC}"
echo -e "  jenny_lead          │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${GREEN}✓${NC}     │ ${RED}✗${NC}   │ ${GREEN}✓${NC}  │ ${RED}✗${NC}"
echo -e "  harry_lead          │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${GREEN}✓${NC}     │ ${GREEN}✓${NC}   │ ${RED}✗${NC}  │ ${RED}✗${NC}"
echo -e "  frank_secops        │  ${RED}✗${NC}     │  ${RED}✗${NC}      │  ${RED}✗${NC}     │ ${RED}✗${NC}   │ ${RED}✗${NC}  │ ${YELLOW}△${NC}"
echo -e "  grace_cto           │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${GREEN}✓${NC}     │ ${RED}✗${NC}   │ ${GREEN}✓${NC}  │ ${YELLOW}△${NC}"
echo -e "  diana_admin         │  ${GREEN}✓${NC}     │  ${GREEN}✓${NC}      │  ${GREEN}✓${NC}     │ ${GREEN}✓${NC}   │ ${GREEN}✓${NC}  │ ${GREEN}✓${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} = 허용  ${RED}✗${NC} = 거부  ${YELLOW}△${NC} = SET ROLE 전환 필요"
echo ""
echo -e "${BOLD}${LINE}${NC}"
echo -e "${BOLD} 검증 완료!${NC}"
echo -e "${BOLD}${LINE}${NC}"

-- ============================================================
-- StarRocks RBAC (Role-Based Access Control) 데모 초기화 스크립트
-- 4-Tier 역할 계층 구조 + 10명 사용자 구성
-- ============================================================

-- ************************************************************
-- Step 1: Tier 1 - 기본 역할 (Base Roles) 생성
-- 원자적 권한 단위로, 상위 역할에서 조합하여 사용
-- ************************************************************

-- 1-1. base_reader: analytics_db의 모든 테이블 읽기 권한
CREATE ROLE IF NOT EXISTS base_reader;
GRANT SELECT ON ALL TABLES IN DATABASE analytics_db TO ROLE base_reader;

-- 1-2. base_writer: analytics_db의 읽기 + 쓰기 + 삭제 권한
CREATE ROLE IF NOT EXISTS base_writer;
GRANT SELECT, INSERT, DELETE ON ALL TABLES IN DATABASE analytics_db TO ROLE base_writer;

-- 1-3. base_ddl: analytics_db에서 테이블 생성/수정/삭제 권한
CREATE ROLE IF NOT EXISTS base_ddl;
GRANT CREATE TABLE ON DATABASE analytics_db TO ROLE base_ddl;
GRANT ALTER, DROP ON ALL TABLES IN DATABASE analytics_db TO ROLE base_ddl;

-- 1-4. catalog_user: MySQL External Catalog 사용 권한
-- USAGE 권한으로 카탈로그에 접근하고, SELECT로 데이터 조회
CREATE ROLE IF NOT EXISTS catalog_user;
GRANT USAGE ON CATALOG mysql_catalog TO ROLE catalog_user;
GRANT SELECT ON ALL TABLES IN ALL DATABASES IN CATALOG mysql_catalog TO ROLE catalog_user;

-- 1-5. mv_creator: Materialized View 생성 권한
-- 분석가가 자주 사용하는 쿼리를 MV로 만들어 성능 최적화
CREATE ROLE IF NOT EXISTS mv_creator;
GRANT CREATE MATERIALIZED VIEW ON DATABASE analytics_db TO ROLE mv_creator;

-- 1-6. task_operator: Task 실행을 위한 INSERT 권한
-- StarRocks에는 SUBMIT TASK 전용 권한이 없음
-- Task는 내부적으로 INSERT를 수행하므로 INSERT 권한이 필요
CREATE ROLE IF NOT EXISTS task_operator;
GRANT INSERT ON ALL TABLES IN DATABASE analytics_db TO ROLE task_operator;

-- 1-7. backup_operator: 백업/복구를 위한 REPOSITORY 권한
CREATE ROLE IF NOT EXISTS backup_operator;
GRANT REPOSITORY ON SYSTEM TO ROLE backup_operator;

-- 1-8. audit_reader: 시스템 통계/감사 조회 권한
-- _statistics_ 데이터베이스에서 내부 통계 정보 조회 가능
CREATE ROLE IF NOT EXISTS audit_reader;
GRANT SELECT ON ALL TABLES IN DATABASE _statistics_ TO ROLE audit_reader;


-- ************************************************************
-- Step 2: Tier 2 - 부서/기능 역할 (Department Roles) 생성
-- Base 역할을 조합하여 부서별 업무에 맞는 역할 구성
-- GRANT role TO ROLE 구문으로 역할 상속 구현
-- ************************************************************

-- 2-1. report_viewer: 리포트 전용 읽기 역할
-- 카탈로그 없이 analytics_db만 조회 가능 (외부 사용자, 인턴용)
CREATE ROLE IF NOT EXISTS report_viewer;
GRANT base_reader TO ROLE report_viewer;

-- 2-2. analytics_team: 분석팀 기본 역할
-- 읽기 + 카탈로그 조회 (MySQL 원본 데이터와 비교 분석 가능)
CREATE ROLE IF NOT EXISTS analytics_team;
GRANT base_reader TO ROLE analytics_team;
GRANT catalog_user TO ROLE analytics_team;

-- 2-3. senior_analyst: 시니어 분석가 역할
-- analytics_team의 모든 권한 + Materialized View 생성
CREATE ROLE IF NOT EXISTS senior_analyst;
GRANT analytics_team TO ROLE senior_analyst;
GRANT mv_creator TO ROLE senior_analyst;

-- 2-4. data_engineering_team: 데이터 엔지니어링팀 역할
-- 쓰기 + DDL + 카탈로그 (파이프라인 구축 및 테이블 관리)
CREATE ROLE IF NOT EXISTS data_engineering_team;
GRANT base_writer TO ROLE data_engineering_team;
GRANT base_ddl TO ROLE data_engineering_team;
GRANT catalog_user TO ROLE data_engineering_team;


-- ************************************************************
-- Step 3: Tier 3 - 리더/매니저 역할 (Lead Roles) 생성
-- 부서 역할에 추가 권한을 더해 리드급 업무 수행
-- ************************************************************

-- 3-1. analytics_lead: 분석팀 리드
-- senior_analyst의 모든 권한 + 쓰기 권한 (결과 저장, 리포트 테이블 생성)
CREATE ROLE IF NOT EXISTS analytics_lead;
GRANT senior_analyst TO ROLE analytics_lead;
GRANT base_writer TO ROLE analytics_lead;

-- 3-2. engineering_lead: 엔지니어링팀 리드
-- data_engineering_team + Task 관리 + 백업 관리
CREATE ROLE IF NOT EXISTS engineering_lead;
GRANT data_engineering_team TO ROLE engineering_lead;
GRANT task_operator TO ROLE engineering_lead;
GRANT backup_operator TO ROLE engineering_lead;

-- 3-3. security_officer: 보안 담당자
-- 감사 로그 조회 + 사용자 관리 (내장 역할 user_admin 활용)
CREATE ROLE IF NOT EXISTS security_officer;
GRANT audit_reader TO ROLE security_officer;
GRANT user_admin TO ROLE security_officer;


-- ************************************************************
-- Step 4: Tier 4 - 플랫폼 관리자 역할 (Super Admin) 생성
-- StarRocks 내장 역할(db_admin, user_admin, cluster_admin) 활용
-- ************************************************************

-- 4-1. platform_admin: 전체 플랫폼 관리자
-- db_admin: 모든 DB/테이블/뷰/함수 관리 권한
-- user_admin: 사용자/역할 생성 및 권한 부여
-- cluster_admin: 노드 관리, 플러그인, 파일, 리소스 그룹 등
CREATE ROLE IF NOT EXISTS platform_admin;
GRANT db_admin TO ROLE platform_admin;
GRANT user_admin TO ROLE platform_admin;
GRANT cluster_admin TO ROLE platform_admin;


-- ************************************************************
-- Step 5: 사용자 생성 (10명)
-- 각 사용자는 서로 다른 역할과 권한 수준을 가짐
-- ************************************************************

-- === 경영/관리 그룹 (3명) ===

-- diana_admin: 플랫폼 관리자 - 시스템 전체 관리
CREATE USER IF NOT EXISTS diana_admin IDENTIFIED BY 'demo_pw1#';

-- frank_secops: 보안 담당자 - 감사 + 사용자 관리
CREATE USER IF NOT EXISTS frank_secops IDENTIFIED BY 'demo_pw1#';

-- grace_cto: CTO - 관리자 + 분석 리드 (다중 역할 보유)
CREATE USER IF NOT EXISTS grace_cto IDENTIFIED BY 'demo_pw1#';

-- === 데이터 엔지니어링팀 (3명) ===

-- harry_lead: 엔지니어링 리드 - DDL + Task + 백업
CREATE USER IF NOT EXISTS harry_lead IDENTIFIED BY 'demo_pw1#';

-- charlie_engineer: 시니어 엔지니어 - DDL + 쓰기 + 카탈로그
CREATE USER IF NOT EXISTS charlie_engineer IDENTIFIED BY 'demo_pw1#';

-- ivan_junior: 주니어 엔지니어 - 쓰기 + 카탈로그 (DDL 불가)
CREATE USER IF NOT EXISTS ivan_junior IDENTIFIED BY 'demo_pw1#';

-- === 분석팀 (3명) ===

-- jenny_lead: 분석팀 리드 - 읽기 + 쓰기 + MV + 카탈로그
CREATE USER IF NOT EXISTS jenny_lead IDENTIFIED BY 'demo_pw1#';

-- alice_analyst: 분석가 - 읽기 + 카탈로그
CREATE USER IF NOT EXISTS alice_analyst IDENTIFIED BY 'demo_pw1#';

-- bob_senior: 시니어 분석가 - 기본은 analytics_team, SET ROLE로 MV 생성
CREATE USER IF NOT EXISTS bob_senior IDENTIFIED BY 'demo_pw1#';

-- === 외부/제한 사용자 (1명) ===

-- kate_intern: 인턴 - analytics_db 읽기만 가능
CREATE USER IF NOT EXISTS kate_intern IDENTIFIED BY 'demo_pw1#';


-- ************************************************************
-- Step 6: 사용자에게 역할 부여
-- ************************************************************

-- 경영/관리 그룹
GRANT platform_admin TO USER diana_admin;
GRANT security_officer TO USER frank_secops;
GRANT platform_admin, analytics_lead TO USER grace_cto;  -- 다중 역할

-- 데이터 엔지니어링팀
GRANT engineering_lead TO USER harry_lead;
GRANT data_engineering_team TO USER charlie_engineer;
GRANT base_writer, catalog_user TO USER ivan_junior;  -- Base 역할 직접 조합

-- 분석팀
GRANT analytics_lead TO USER jenny_lead;
GRANT analytics_team TO USER alice_analyst;
GRANT senior_analyst TO USER bob_senior;

-- 외부/제한 사용자
GRANT report_viewer TO USER kate_intern;


-- ************************************************************
-- Step 7: 기본 역할 (DEFAULT ROLE) 설정
--
-- DEFAULT ROLE이란?
--   사용자가 로그인했을 때 자동으로 활성화되는 역할입니다.
--   ALL: 부여받은 모든 역할이 자동 활성화
--   특정 역할만 지정: 해당 역할만 활성화, 나머지는 SET ROLE로 전환 필요
--
-- 이를 통해 "최소 권한 원칙"을 구현할 수 있습니다.
-- 예: CTO는 평소 분석 리드로 작업하다가, 관리 필요시 SET ROLE ALL
-- ************************************************************

-- diana_admin: 모든 역할 활성화 (관리자이므로)
SET DEFAULT ROLE ALL TO diana_admin;

-- frank_secops: 모든 역할 활성화
SET DEFAULT ROLE ALL TO frank_secops;

-- grace_cto: 기본은 analytics_lead만 (최소 권한 원칙)
-- 관리 작업 필요시 SET ROLE ALL 또는 SET ROLE platform_admin
SET DEFAULT ROLE analytics_lead TO grace_cto;

-- harry_lead: 모든 역할 활성화
SET DEFAULT ROLE ALL TO harry_lead;

-- charlie_engineer: 모든 역할 활성화
SET DEFAULT ROLE ALL TO charlie_engineer;

-- ivan_junior: 기본은 base_writer만 (카탈로그는 필요시 전환)
SET DEFAULT ROLE base_writer TO ivan_junior;

-- jenny_lead: 모든 역할 활성화
SET DEFAULT ROLE ALL TO jenny_lead;

-- alice_analyst: 모든 역할 활성화
SET DEFAULT ROLE ALL TO alice_analyst;

-- bob_senior: 기본은 analytics_team만 (MV 생성은 필요시 전환)
-- senior_analyst 역할로 전환하면 mv_creator 권한도 함께 활성화
SET DEFAULT ROLE analytics_team TO bob_senior;

-- kate_intern: 모든 역할 활성화
SET DEFAULT ROLE ALL TO kate_intern;


-- ************************************************************
-- Step 8: 설정 확인
-- ************************************************************

-- 생성된 역할 목록 확인
SHOW ROLES;

-- 각 사용자의 권한 확인 (주요 사용자)
SHOW GRANTS FOR diana_admin;
SHOW GRANTS FOR grace_cto;
SHOW GRANTS FOR harry_lead;
SHOW GRANTS FOR bob_senior;
SHOW GRANTS FOR kate_intern;

.PHONY: help install init setup-external start stop restart status enable disable \
        configure-listen configure-auth firewall uninstall clean check-env init-env \
        tune-kernel tune-limits tune-hugepages tune-all show-tuning \
        test test-connection test-database test-performance \
        offline-download offline-createrepo offline-package offline-install offline-setup-repo \
        offline-install-pkg offline-full-install offline-package-all offline-workflow \
        iso-mount iso-setup-repo iso-unmount iso-all \
        apache-install apache-configure apache-firewall apache-start apache-stop apache-restart \
        apache-status apache-enable apache-disable apache-test apache-all apache-uninstall \
        apache-offline-download apache-offline-package \
        tomcat-install tomcat-configure tomcat-firewall tomcat-start tomcat-stop tomcat-restart \
        tomcat-status tomcat-enable tomcat-disable tomcat-test tomcat-all tomcat-uninstall tomcat-logs \
        tomcat-offline-download tomcat-offline-createrepo tomcat-offline-package \
        tomcat-offline-package-all tomcat-offline-setup-repo tomcat-offline-install-pkg \
        tomcat-offline-install tomcat-offline-full-install \
        web-all web-test web-offline-package stack-all stack-test

# 환경 변수 로드
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# 기본값 설정 - 커널 튜닝
VM_SWAPPINESS ?= 10
VM_DIRTY_BACKGROUND_RATIO ?= 5
VM_DIRTY_RATIO ?= 15
VM_OVERCOMMIT_MEMORY ?= 0
NET_CORE_SOMAXCONN ?= 4096
NET_IPV4_TCP_MAX_SYN_BACKLOG ?= 4096
NET_IPV4_TCP_KEEPALIVE_TIME ?= 600
NET_IPV4_TCP_KEEPALIVE_PROBES ?= 5
NET_IPV4_TCP_KEEPALIVE_INTVL ?= 10
KERNEL_SHMMAX ?= 17179869184
KERNEL_SHMALL ?= 4194304
ULIMIT_NOFILE ?= 65536
ULIMIT_NPROC ?= unlimited
ULIMIT_MEMLOCK ?= unlimited
ENABLE_HUGE_PAGES ?= false
HUGE_PAGES_COUNT ?=
PG_SHARED_BUFFERS ?= 4GB

# 기본값 설정 - PostgreSQL
PG_VERSION ?= 16
PG_MAJOR_VERSION ?= 16
EL_VERSION ?= 9
PG_PORT ?= 5432
PG_LISTEN_ADDRESSES ?= *
PG_ALLOWED_CIDR ?= 0.0.0.0/0
PG_AUTH_METHOD ?= scram-sha-256
ENABLE_FIREWALL ?= true
PG_OS_USER ?= postgres

# 동적 경로 설정
PG_BIN_DIR := /usr/pgsql-$(PG_VERSION)/bin
PG_DATA_DIR := /var/lib/pgsql/$(PG_VERSION)/data
PG_SERVICE_NAME := postgresql-$(PG_VERSION)

# 색상 출력
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## 사용 가능한 명령어 목록 표시
	@printf "$(BLUE)PostgreSQL $(PG_VERSION) 설치 및 관리 도구$(NC)\n"
	@printf "\n"
	@printf "$(GREEN)사용 가능한 명령어:$(NC)\n"
	@grep -E '^[a-zA-Z_-]+:.* ## ' Makefile | sed 's/:.*## /\t/' | awk -F'\t' '{printf "  $(YELLOW)%-28s$(NC) %s\n", $$1, $$2}'
	@printf "\n"
	@printf "$(BLUE)현재 설정:$(NC)\n"
	@printf "  PostgreSQL 버전: $(PG_VERSION)\n"
	@printf "  데이터 디렉토리: $(PG_DATA_DIR)\n"
	@printf "  서비스 이름: $(PG_SERVICE_NAME)\n"
	@printf "  포트: $(PG_PORT)\n"

check-env: ## 환경 변수 확인
	@if [ ! -f .env ]; then \
		printf "$(RED)오류: .env 파일이 없습니다.$(NC)\n"; \
		printf "$(YELLOW)다음 명령어로 생성하세요: make init-env$(NC)\n"; \
		exit 1; \
	else \
		printf "$(GREEN)✓ .env 파일이 존재합니다.$(NC)\n"; \
	fi
	@echo ""
	@printf "$(BLUE)PostgreSQL 설정:$(NC)\n"
	@echo "  PG_VERSION=$(PG_VERSION)"
	@echo "  PG_DATA_DIR=$(PG_DATA_DIR)"
	@echo "  PG_PORT=$(PG_PORT)"
	@echo "  PG_LISTEN_ADDRESSES=$(PG_LISTEN_ADDRESSES)"
	@echo "  PG_ALLOWED_CIDR=$(PG_ALLOWED_CIDR)"
	@echo "  PG_AUTH_METHOD=$(PG_AUTH_METHOD)"
	@echo ""
	@printf "$(BLUE)오프라인 패키징 설정:$(NC)\n"
	@echo "  OFFLINE_REPO_DIR=$(OFFLINE_REPO_DIR)"
	@echo "  OFFLINE_ARCHIVE_NAME=$(OFFLINE_ARCHIVE_NAME)"
	@echo "  ISO_FILE=$(ISO_FILE)"

init-env: ## .env 파일 초기화 (.env.example 복사)
	@if [ -f .env ]; then \
		printf "$(YELLOW).env 파일이 이미 존재합니다.$(NC)\n"; \
		read -p "덮어쓰시겠습니까? (y/N): " confirm; \
		if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
			cp .env.example .env; \
			printf "$(GREEN)✓ .env 파일이 생성되었습니다.$(NC)\n"; \
		else \
			printf "$(YELLOW)취소되었습니다.$(NC)\n"; \
		fi; \
	else \
		cp .env.example .env; \
		printf "$(GREEN)✓ .env 파일이 생성되었습니다.$(NC)\n"; \
	fi
	@echo ""
	@printf "$(YELLOW).env 파일을 편집하여 환경에 맞게 설정하세요:$(NC)\n"
	@printf "  $(YELLOW)vi .env$(NC)\n"

# ===================================================================
# 시스템 커널 튜닝
# ===================================================================

tune-kernel: ## 커널 파라미터 최적화 설정 (/etc/sysctl.d/)
	@printf "$(BLUE)커널 파라미터 최적화 설정...$(NC)\n"

	@printf "$(YELLOW)1. sysctl 설정 파일 생성: /etc/sysctl.d/99-postgresql.conf$(NC)\n"
	@echo "# PostgreSQL 성능 최적화를 위한 커널 파라미터" | sudo tee /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# --- 메모리 관리 (Memory) ---" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# 스왑 사용 억제: DB는 메모리에서 작동해야 빠릅니다" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "vm.swappiness = $(VM_SWAPPINESS)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# Dirty Page 관리: I/O 스파이크 방지" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "vm.dirty_background_ratio = $(VM_DIRTY_BACKGROUND_RATIO)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "vm.dirty_ratio = $(VM_DIRTY_RATIO)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# Overcommit 설정" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "vm.overcommit_memory = $(VM_OVERCOMMIT_MEMORY)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# --- 네트워크 (Network) ---" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# 연결 대기 큐 크기 증가" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "net.core.somaxconn = $(NET_CORE_SOMAXCONN)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "net.ipv4.tcp_max_syn_backlog = $(NET_IPV4_TCP_MAX_SYN_BACKLOG)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# Keepalive 시간 단축: 죽은 연결 빠른 감지" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "net.ipv4.tcp_keepalive_time = $(NET_IPV4_TCP_KEEPALIVE_TIME)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "net.ipv4.tcp_keepalive_probes = $(NET_IPV4_TCP_KEEPALIVE_PROBES)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "net.ipv4.tcp_keepalive_intvl = $(NET_IPV4_TCP_KEEPALIVE_INTVL)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# --- 공유 메모리 (Shared Memory) ---" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "# Huge Pages 사용 시 필요" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "kernel.shmmax = $(KERNEL_SHMMAX)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null
	@echo "kernel.shmall = $(KERNEL_SHMALL)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null

	@printf "$(YELLOW)2. 커널 파라미터 적용$(NC)\n"
	sudo sysctl --system

	@printf "$(GREEN)✓ 커널 파라미터 최적화 완료$(NC)\n"

tune-limits: ## 리소스 제한 설정 (/etc/security/limits.d/)
	@printf "$(BLUE)리소스 제한(ulimit) 설정...$(NC)\n"

	@printf "$(YELLOW)PostgreSQL 사용자 리소스 제한 설정: /etc/security/limits.d/postgresql.conf$(NC)\n"
	@echo "# PostgreSQL 리소스 제한 설정" | sudo tee /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "# 파일 디스크립터 (nofile)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "$(PG_OS_USER)    soft    nofile      $(ULIMIT_NOFILE)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "$(PG_OS_USER)    hard    nofile      $(ULIMIT_NOFILE)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "# 프로세스 수 (nproc)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "$(PG_OS_USER)    soft    nproc       $(ULIMIT_NPROC)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "$(PG_OS_USER)    hard    nproc       $(ULIMIT_NPROC)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "# 메모리 잠금 (memlock) - Huge Pages용" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "$(PG_OS_USER)    soft    memlock     $(ULIMIT_MEMLOCK)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null
	@echo "$(PG_OS_USER)    hard    memlock     $(ULIMIT_MEMLOCK)" | sudo tee -a /etc/security/limits.d/postgresql.conf > /dev/null

	@printf "$(GREEN)✓ 리소스 제한 설정 완료$(NC)\n"
	@printf "$(YELLOW)주의: 설정 적용을 위해 postgres 사용자 재로그인 또는 시스템 재부팅 필요$(NC)\n"

tune-hugepages: ## Huge Pages 설정
	@if [ "$(ENABLE_HUGE_PAGES)" = "true" ]; then \
		printf "$(BLUE)Huge Pages 설정...$(NC)\n"; \
		if [ -z "$(HUGE_PAGES_COUNT)" ]; then \
			printf "$(YELLOW)Huge Pages 수를 자동 계산합니다...$(NC)\n"; \
			SHARED_BUFFERS_MB=$$(echo "$(PG_SHARED_BUFFERS)" | sed 's/GB/*1024/; s/MB//; s/KB\/1024/' | bc); \
			CALCULATED_PAGES=$$(( $$SHARED_BUFFERS_MB / 2 )); \
			printf "$(BLUE)  shared_buffers: $(PG_SHARED_BUFFERS) = $${SHARED_BUFFERS_MB}MB$(NC)\n"; \
			printf "$(BLUE)  계산된 Huge Pages: $${CALCULATED_PAGES}$(NC)\n"; \
			echo "vm.nr_hugepages = $${CALCULATED_PAGES}" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null; \
		else \
			printf "$(BLUE)Huge Pages 수동 설정: $(HUGE_PAGES_COUNT)$(NC)\n"; \
			echo "vm.nr_hugepages = $(HUGE_PAGES_COUNT)" | sudo tee -a /etc/sysctl.d/99-postgresql.conf > /dev/null; \
		fi; \
		sudo sysctl --system; \
		printf "$(GREEN)✓ Huge Pages 설정 완료$(NC)\n"; \
		printf "$(YELLOW)postgresql.conf에 huge_pages = try 설정을 추가하세요.$(NC)\n"; \
	else \
		printf "$(YELLOW)Huge Pages 설정 건너뜀 (ENABLE_HUGE_PAGES=false)$(NC)\n"; \
	fi

tune-all: tune-kernel tune-limits tune-hugepages ## 모든 시스템 튜닝 적용
	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)시스템 튜닝 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)적용된 설정:$(NC)\n"
	@echo "  - 커널 파라미터: /etc/sysctl.d/99-postgresql.conf"
	@echo "  - 리소스 제한: /etc/security/limits.d/postgresql.conf"
	@if [ "$(ENABLE_HUGE_PAGES)" = "true" ]; then \
		echo "  - Huge Pages: 활성화"; \
	fi
	@echo ""
	@printf "$(YELLOW)주의: 일부 설정은 시스템 재부팅 후 완전히 적용됩니다.$(NC)\n"

show-tuning: ## 현재 적용된 튜닝 값 확인
	@printf "$(BLUE)현재 커널 파라미터:$(NC)\n"
	@echo ""
	@printf "$(YELLOW)[메모리]$(NC)\n"
	@sysctl vm.swappiness vm.dirty_background_ratio vm.dirty_ratio vm.overcommit_memory 2>/dev/null || echo "  (미설정)"
	@echo ""
	@printf "$(YELLOW)[네트워크]$(NC)\n"
	@sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo "  (미설정)"
	@sysctl net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_probes net.ipv4.tcp_keepalive_intvl 2>/dev/null || echo "  (미설정)"
	@echo ""
	@printf "$(YELLOW)[공유 메모리]$(NC)\n"
	@sysctl kernel.shmmax kernel.shmall 2>/dev/null || echo "  (미설정)"
	@echo ""
	@printf "$(YELLOW)[Huge Pages]$(NC)\n"
	@sysctl vm.nr_hugepages 2>/dev/null || echo "  (미설정)"
	@grep HugePages /proc/meminfo 2>/dev/null || echo "  (정보 없음)"
	@echo ""
	@printf "$(YELLOW)[리소스 제한 - postgres 사용자]$(NC)\n"
	@if id $(PG_OS_USER) &>/dev/null; then \
		sudo -u $(PG_OS_USER) bash -c 'ulimit -n' 2>/dev/null && echo "  open files: $$(sudo -u $(PG_OS_USER) bash -c 'ulimit -n')" || echo "  (확인 불가)"; \
		sudo -u $(PG_OS_USER) bash -c 'ulimit -u' 2>/dev/null && echo "  max processes: $$(sudo -u $(PG_OS_USER) bash -c 'ulimit -u')" || echo "  (확인 불가)"; \
	else \
		echo "  $(PG_OS_USER) 사용자가 아직 생성되지 않았습니다."; \
	fi

# ===================================================================
# PostgreSQL 설치 및 관리
# ==================================================================="

install: check-env ## PostgreSQL 설치 (저장소 추가 + 패키지 설치)
	@printf "$(BLUE)PostgreSQL $(PG_VERSION) 설치 시작...$(NC)\n"

	@printf "$(YELLOW)1. PGDG 저장소 추가$(NC)\n"
	sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(EL_VERSION)-x86_64/pgdg-redhat-repo-latest.noarch.rpm

	@printf "$(YELLOW)2. 기본 PostgreSQL 모듈 비활성화$(NC)\n"
	sudo dnf -qy module disable postgresql

	@printf "$(YELLOW)3. PostgreSQL $(PG_VERSION) 서버 설치$(NC)\n"
	sudo dnf install -y postgresql$(PG_VERSION)-server postgresql$(PG_VERSION)-contrib

	@printf "$(GREEN)✓ PostgreSQL $(PG_VERSION) 설치 완료$(NC)\n"

init: ## 데이터베이스 초기화 (initdb)
	@printf "$(BLUE)PostgreSQL 데이터베이스 초기화...$(NC)\n"

	@if [ -d "$(PG_DATA_DIR)" ] && [ "$$(ls -A $(PG_DATA_DIR))" ]; then \
		printf "$(RED)오류: 데이터 디렉토리가 이미 존재합니다: $(PG_DATA_DIR)$(NC)\n"; \
		printf "$(YELLOW)초기화를 강제하려면 먼저 'make clean'을 실행하세요.$(NC)\n"; \
		exit 1; \
	fi

	sudo $(PG_BIN_DIR)/postgresql-$(PG_VERSION)-setup initdb
	@printf "$(GREEN)✓ 데이터베이스 초기화 완료$(NC)\n"

configure-listen: ## listen_addresses 설정 (외부 접속 허용)
	@printf "$(BLUE)listen_addresses 설정: $(PG_LISTEN_ADDRESSES)$(NC)\n"

	@if ! grep -q "^listen_addresses" $(PG_DATA_DIR)/postgresql.conf; then \
		sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '$(PG_LISTEN_ADDRESSES)'/" $(PG_DATA_DIR)/postgresql.conf; \
	else \
		sudo sed -i "s/^listen_addresses.*/listen_addresses = '$(PG_LISTEN_ADDRESSES)'/" $(PG_DATA_DIR)/postgresql.conf; \
	fi

	@printf "$(GREEN)✓ listen_addresses 설정 완료$(NC)\n"

configure-auth: ## pg_hba.conf 인증 설정
	@printf "$(BLUE)pg_hba.conf 인증 설정: $(PG_AUTH_METHOD)$(NC)\n"

	@if ! grep -q "# Custom external access" $(PG_DATA_DIR)/pg_hba.conf; then \
		echo "" | sudo tee -a $(PG_DATA_DIR)/pg_hba.conf > /dev/null; \
		echo "# Custom external access" | sudo tee -a $(PG_DATA_DIR)/pg_hba.conf > /dev/null; \
		echo "host    all             all             $(PG_ALLOWED_CIDR)              $(PG_AUTH_METHOD)" | sudo tee -a $(PG_DATA_DIR)/pg_hba.conf > /dev/null; \
	else \
		printf "$(YELLOW)외부 접속 설정이 이미 존재합니다.$(NC)\n"; \
	fi

	@printf "$(GREEN)✓ 인증 설정 완료$(NC)\n"

firewall: ## 방화벽 설정 (포트 5432 열기)
	@if [ "$(ENABLE_FIREWALL)" = "true" ]; then \
		printf "$(BLUE)방화벽 설정...$(NC)\n"; \
		sudo firewall-cmd --permanent --add-service=postgresql 2>/dev/null || sudo firewall-cmd --permanent --add-port=$(PG_PORT)/tcp; \
		sudo firewall-cmd --reload; \
		printf "$(GREEN)✓ 방화벽 설정 완료$(NC)\n"; \
	else \
		printf "$(YELLOW)방화벽 설정 건너뜀 (ENABLE_FIREWALL=false)$(NC)\n"; \
	fi

setup-external: configure-listen configure-auth firewall restart ## 외부 접속 설정 (listen + auth + firewall)
	@printf "$(GREEN)✓ 외부 접속 설정 완료$(NC)\n"

start: ## PostgreSQL 서비스 시작
	@printf "$(BLUE)PostgreSQL 서비스 시작...$(NC)\n"
	sudo systemctl start $(PG_SERVICE_NAME)
	@printf "$(GREEN)✓ 서비스 시작 완료$(NC)\n"

stop: ## PostgreSQL 서비스 중지
	@printf "$(BLUE)PostgreSQL 서비스 중지...$(NC)\n"
	sudo systemctl stop $(PG_SERVICE_NAME)
	@printf "$(GREEN)✓ 서비스 중지 완료$(NC)\n"

restart: ## PostgreSQL 서비스 재시작
	@printf "$(BLUE)PostgreSQL 서비스 재시작...$(NC)\n"
	sudo systemctl restart $(PG_SERVICE_NAME)
	@printf "$(GREEN)✓ 서비스 재시작 완료$(NC)\n"

status: ## PostgreSQL 서비스 상태 확인
	@sudo systemctl status $(PG_SERVICE_NAME) --no-pager

enable: ## 부팅 시 자동 시작 활성화
	@printf "$(BLUE)부팅 시 자동 시작 활성화...$(NC)\n"
	sudo systemctl enable $(PG_SERVICE_NAME)
	@printf "$(GREEN)✓ 자동 시작 활성화 완료$(NC)\n"

disable: ## 부팅 시 자동 시작 비활성화
	@printf "$(BLUE)부팅 시 자동 시작 비활성화...$(NC)\n"
	sudo systemctl disable $(PG_SERVICE_NAME)
	@printf "$(GREEN)✓ 자동 시작 비활성화 완료$(NC)\n"

enable-start: enable start ## 자동 시작 활성화 + 서비스 시작

all: tune-all install init enable-start setup-external ## 전체 설치 및 설정 (tune + install + init + enable + start + external)
	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)PostgreSQL $(PG_VERSION) 설치 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)다음 단계:$(NC)\n"
	@echo "  1. postgres 사용자 비밀번호 설정:"
	@printf "     $(YELLOW)sudo passwd postgres$(NC)\n"
	@echo ""
	@echo "  2. PostgreSQL 접속:"
	@printf "     $(YELLOW)sudo -u postgres psql$(NC)\n"
	@echo ""
	@echo "  3. 서비스 상태 확인:"
	@printf "     $(YELLOW)make status$(NC)\n"
	@echo ""
	@echo "  4. 튜닝 설정 확인:"
	@printf "     $(YELLOW)make show-tuning$(NC)\n"

clean: stop ## 데이터 디렉토리 삭제 (주의: 모든 데이터 삭제)
	@printf "$(RED)경고: 데이터 디렉토리를 삭제합니다!$(NC)\n"
	@read -p "계속하시겠습니까? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		sudo rm -rf $(PG_DATA_DIR); \
		printf "$(GREEN)✓ 데이터 디렉토리 삭제 완료$(NC)\n"; \
	else \
		printf "$(YELLOW)취소되었습니다.$(NC)\n"; \
	fi

uninstall: stop disable ## PostgreSQL 제거 (패키지 삭제)
	@printf "$(YELLOW)PostgreSQL $(PG_VERSION) 제거...$(NC)\n"
	sudo dnf remove -y postgresql$(PG_VERSION)-server postgresql$(PG_VERSION)-contrib
	@printf "$(GREEN)✓ PostgreSQL 제거 완료$(NC)\n"
	@printf "$(YELLOW)데이터를 삭제하려면 'make clean'을 실행하세요.$(NC)\n"

logs: ## PostgreSQL 로그 확인
	sudo journalctl -u $(PG_SERVICE_NAME) -f

version: ## PostgreSQL 버전 확인
	@if [ -f "$(PG_BIN_DIR)/psql" ]; then \
		$(PG_BIN_DIR)/psql --version; \
	else \
		printf "$(RED)PostgreSQL이 설치되어 있지 않습니다.$(NC)\n"; \
	fi
# ===================================================================
# 테스트 및 검증
# ===================================================================

test-connection: ## PostgreSQL 연결 테스트
	@printf "$(BLUE)PostgreSQL 연결 테스트...$(NC)\n"
	@sudo -u $(PG_OS_USER) psql -c "SELECT version();" || (printf "$(RED)연결 실패$(NC)\n" && exit 1)
	@printf "$(GREEN)✓ 연결 테스트 성공$(NC)\n"

test-database: ## 데이터베이스 생성/삭제 테스트
	@printf "$(BLUE)데이터베이스 CRUD 테스트...$(NC)\n"

	@printf "$(YELLOW)1. 테스트 테이블 생성$(NC)\n"
	@sudo -u $(PG_OS_USER) psql -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(100), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

	@printf "$(YELLOW)2. 데이터 삽입$(NC)\n"
	@sudo -u $(PG_OS_USER) psql -c "INSERT INTO test_table (name) VALUES ('Test Data 1'), ('Test Data 2'), ('Test Data 3');"

	@printf "$(YELLOW)3. 데이터 조회$(NC)\n"
	@sudo -u $(PG_OS_USER) psql -c "SELECT * FROM test_table;"

	@printf "$(YELLOW)4. 데이터 개수 확인$(NC)\n"
	@sudo -u $(PG_OS_USER) psql -t -c "SELECT COUNT(*) FROM test_table;" | xargs echo "레코드 수:"

	@printf "$(YELLOW)5. 테이블 삭제$(NC)\n"
	@sudo -u $(PG_OS_USER) psql -c "DROP TABLE IF EXISTS test_table;"

	@printf "$(GREEN)✓ 데이터베이스 테스트 완료$(NC)\n"

test-performance: ## 간단한 성능 테스트 (pgbench)
	@printf "$(BLUE)PostgreSQL 성능 테스트...$(NC)\n"

	@printf "$(YELLOW)1. pgbench 테스트 DB 생성$(NC)\n"
	@sudo -u $(PG_OS_USER) createdb -O $(PG_OS_USER) pgbench_test 2>/dev/null || true

	@printf "$(YELLOW)2. pgbench 초기화 (scale=10)$(NC)\n"
	@sudo -u $(PG_OS_USER) pgbench -i -s 10 pgbench_test

	@printf "$(YELLOW)3. 성능 테스트 실행 (10 clients, 1000 transactions)$(NC)\n"
	@sudo -u $(PG_OS_USER) pgbench -c 10 -j 2 -t 1000 pgbench_test

	@printf "$(YELLOW)4. 테스트 DB 삭제$(NC)\n"
	@sudo -u $(PG_OS_USER) dropdb pgbench_test

	@printf "$(GREEN)✓ 성능 테스트 완료$(NC)\n"

test: test-connection test-database ## 전체 테스트 실행 (연결 + 데이터베이스)
	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)모든 테스트 통과!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"

# ===================================================================
# 오프라인 패키징 (인터넷 연결된 서버에서 실행)
# ===================================================================

offline-download: ## PostgreSQL RPM 패키지 다운로드
	@printf "$(BLUE)PostgreSQL 오프라인 패키지 다운로드...$(NC)\n"

	@printf "$(YELLOW)1. 다운로드 디렉토리 생성$(NC)\n"
	@mkdir -p $(OFFLINE_REPO_DIR)/rpms

	@printf "$(YELLOW)2. PGDG 저장소 설정 확인$(NC)\n"
	@if ! dnf repolist | grep -q pgdg$(PG_VERSION); then \
		printf "$(YELLOW)PGDG 저장소 추가 중...$(NC)\n"; \
		sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(EL_VERSION)-x86_64/pgdg-redhat-repo-latest.noarch.rpm; \
		sudo dnf -qy module disable postgresql; \
	fi

	@printf "$(YELLOW)3. PostgreSQL 패키지 다운로드$(NC)\n"
	@if [ -n "$(OFFLINE_PG_VERSION)" ]; then \
		echo "  지정된 버전: $(OFFLINE_PG_VERSION)"; \
		cd $(OFFLINE_REPO_DIR)/rpms && dnf download --resolve --alldeps \
			postgresql$(PG_VERSION)-server-$(OFFLINE_PG_VERSION) \
			postgresql$(PG_VERSION)-contrib-$(OFFLINE_PG_VERSION); \
	else \
		echo "  최신 버전 다운로드"; \
		cd $(OFFLINE_REPO_DIR)/rpms && dnf download --resolve --alldeps \
			postgresql$(PG_VERSION)-server \
			postgresql$(PG_VERSION)-contrib; \
	fi

	@printf "$(YELLOW)4. createrepo 도구 다운로드$(NC)\n"
	@cd $(OFFLINE_REPO_DIR)/rpms && dnf download --resolve createrepo_c

	@printf "$(GREEN)✓ 패키지 다운로드 완료$(NC)\n"
	@printf "$(BLUE)다운로드 위치: $(OFFLINE_REPO_DIR)/rpms$(NC)\n"
	@ls $(OFFLINE_REPO_DIR)/rpms/*.rpm 2>/dev/null | wc -l | xargs echo "  총 RPM 파일 수:"

offline-createrepo: ## createrepo 실행하여 repository 메타데이터 생성
	@printf "$(BLUE)Repository 메타데이터 생성...$(NC)\n"

	@if ! command -v createrepo_c &> /dev/null; then \
		printf "$(YELLOW)createrepo_c 설치 중...$(NC)\n"; \
		sudo dnf install -y createrepo_c; \
	fi

	@printf "$(YELLOW)createrepo 실행$(NC)\n"
	@createrepo_c $(OFFLINE_REPO_DIR)/rpms/

	@printf "$(GREEN)✓ Repository 메타데이터 생성 완료$(NC)\n"

offline-package: offline-download offline-createrepo ## 오프라인 패키지 생성 및 압축
	@printf "$(BLUE)오프라인 패키지 압축...$(NC)\n"

	@printf "$(YELLOW)1. 설치 스크립트 복사$(NC)\n"
	@cp -f scripts/offline-setup-repo.sh $(OFFLINE_REPO_DIR)/
	@chmod +x $(OFFLINE_REPO_DIR)/offline-setup-repo.sh

	@printf "$(YELLOW)2. README 파일 생성$(NC)\n"
	@echo "PostgreSQL $(PG_VERSION) 오프라인 설치 패키지" > $(OFFLINE_REPO_DIR)/README.txt
	@echo "========================================" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "## 설치 방법" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "1. 압축 해제:" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   tar -xzf $(OFFLINE_ARCHIVE_NAME)" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "2. Repository 설정:" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   cd $(notdir $(OFFLINE_REPO_DIR))" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   sudo bash offline-setup-repo.sh" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "3. PostgreSQL 설치:" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   sudo dnf install -y postgresql$(PG_VERSION)-server postgresql$(PG_VERSION)-contrib" >> $(OFFLINE_REPO_DIR)/README.txt

	@printf "$(YELLOW)3. 압축 파일 생성$(NC)\n"
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf $(OFFLINE_ARCHIVE_NAME) $(notdir $(OFFLINE_REPO_DIR))

	@printf "$(GREEN)✓ 오프라인 패키지 생성 완료$(NC)\n"
	@echo ""
	@printf "$(BLUE)압축 파일: $(dir $(OFFLINE_REPO_DIR))$(OFFLINE_ARCHIVE_NAME)$(NC)\n"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))$(OFFLINE_ARCHIVE_NAME) 2>/dev/null || true
	@echo ""
	@printf "$(YELLOW)이 파일을 오프라인 서버로 복사하여 사용하세요.$(NC)\n"

# ===================================================================
# 온라인 패키징 전체 플로우 (ISO 기반 종속성 + PostgreSQL 패키지)
# ===================================================================

offline-package-all: check-env ## [온라인] ISO 로컬 repo 설정 후 전체 오프라인 패키지 생성
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)오프라인 패키지 생성 시작 (ISO 기반)$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""

	@if [ -z "$(ISO_FILE)" ]; then \
		printf "$(RED)오류: .env 파일에 ISO_FILE이 설정되지 않았습니다.$(NC)\n"; \
		printf "$(YELLOW).env 파일을 편집하여 ISO_FILE 경로를 설정하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1단계: ISO 마운트 및 로컬 Repository 설정$(NC)\n"
	$(MAKE) iso-mount
	$(MAKE) iso-setup-repo

	@echo ""
	@printf "$(YELLOW)2단계: PGDG 온라인 저장소 추가$(NC)\n"
	@if ! dnf repolist | grep -q pgdg$(PG_VERSION); then \
		sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(EL_VERSION)-x86_64/pgdg-redhat-repo-latest.noarch.rpm; \
		sudo dnf -qy module disable postgresql; \
	else \
		printf "$(GREEN)✓ PGDG 저장소 이미 설정됨$(NC)\n"; \
	fi

	@echo ""
	@printf "$(YELLOW)3단계: PostgreSQL 패키지 다운로드$(NC)\n"
	$(MAKE) offline-download

	@echo ""
	@printf "$(YELLOW)4단계: Repository 메타데이터 생성$(NC)\n"
	$(MAKE) offline-createrepo

	@echo ""
	@printf "$(YELLOW)5단계: 오프라인 패키지 압축$(NC)\n"
	@printf "$(YELLOW)5-1. 설치 스크립트 복사$(NC)\n"
	@cp -f scripts/offline-setup-repo.sh $(OFFLINE_REPO_DIR)/
	@chmod +x $(OFFLINE_REPO_DIR)/offline-setup-repo.sh

	@printf "$(YELLOW)5-2. README 파일 생성$(NC)\n"
	@echo "PostgreSQL $(PG_VERSION) 오프라인 설치 패키지" > $(OFFLINE_REPO_DIR)/README.txt
	@echo "========================================" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "## 오프라인 서버 설치 방법" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "1. 패키지 파일과 ISO 파일을 오프라인 서버로 복사" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "2. 압축 해제:" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   tar -xzf $(OFFLINE_ARCHIVE_NAME)" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "3. .env 파일에서 ISO_FILE 경로 설정:" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   vi .env" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   # ISO_FILE=/path/to/rhel-9.6-x86_64-dvd.iso" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "4. 전체 설치 (권장):" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   make offline-full-install" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "5. 또는 단계별 설치:" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   make iso-mount" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   make iso-setup-repo" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   make offline-install" >> $(OFFLINE_REPO_DIR)/README.txt
	@echo "   make init enable-start setup-external" >> $(OFFLINE_REPO_DIR)/README.txt

	@printf "$(YELLOW)5-3. 압축 파일 생성$(NC)\n"
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf $(OFFLINE_ARCHIVE_NAME) $(notdir $(OFFLINE_REPO_DIR))

	@echo ""
	@printf "$(YELLOW)6단계: ISO 마운트 해제$(NC)\n"
	$(MAKE) iso-unmount

	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)오프라인 패키지 생성 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)생성된 파일:$(NC)\n"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))$(OFFLINE_ARCHIVE_NAME) 2>/dev/null || true
	@echo ""
	@printf "$(YELLOW)오프라인 서버에서 설치 방법:$(NC)\n"
	@echo "  1. 패키지, ISO 파일, 프로젝트 디렉토리를 오프라인 서버로 복사"
	@echo "  2. 압축 해제: tar -xzf $(OFFLINE_ARCHIVE_NAME) -C /root/"
	@echo "  3. .env 파일에서 ISO_FILE 경로 설정"
	@echo "  4. 설치 실행: make offline-full-install"

offline-workflow: ## 오프라인 설치 전체 워크플로우 안내
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)PostgreSQL $(PG_VERSION) 오프라인 설치 워크플로우$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""
	@printf "$(GREEN)[ 사전 준비 ]$(NC)\n"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@printf "  $(YELLOW)1. 환경 설정 파일 생성$(NC)\n"
	@echo "     make init-env"
	@echo ""
	@printf "  $(YELLOW)2. .env 파일 편집 (ISO_FILE 경로 설정)$(NC)\n"
	@echo "     vi .env"
	@echo "     # ISO_FILE=/path/to/rhel-9.6-x86_64-dvd.iso"
	@echo ""
	@echo ""
	@printf "$(GREEN)[ 온라인 서버 작업 ]$(NC)\n"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@printf "  $(YELLOW)1. 오프라인 패키지 생성$(NC)\n"
	@echo "     make offline-package-all"
	@echo ""
	@printf "  $(YELLOW)2. 생성된 파일 확인$(NC)\n"
	@echo "     - $(OFFLINE_ARCHIVE_NAME)"
	@echo "     - RHEL 9.6 ISO 파일"
	@echo ""
	@printf "  $(YELLOW)3. 파일 전송$(NC)\n"
	@echo "     위 2개 파일을 오프라인 서버로 복사 (USB, SCP 등)"
	@echo ""
	@echo ""
	@printf "$(GREEN)[ 오프라인 서버 작업 ]$(NC)\n"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@printf "  $(YELLOW)1. 프로젝트 디렉토리 복사$(NC)\n"
	@echo "     Makefile, scripts/, .env 파일을 오프라인 서버로 복사"
	@echo ""
	@printf "  $(YELLOW)2. 패키지 압축 해제$(NC)\n"
	@echo "     tar -xzf $(OFFLINE_ARCHIVE_NAME) -C /root/"
	@echo ""
	@printf "  $(YELLOW)3. .env 파일에서 ISO_FILE 경로 설정$(NC)\n"
	@echo "     vi .env"
	@echo "     # ISO_FILE=/path/to/rhel-9.6-x86_64-dvd.iso"
	@echo ""
	@printf "  $(YELLOW)4. 전체 설치 (권장 - 한번에 실행)$(NC)\n"
	@echo "     make offline-full-install"
	@echo ""
	@printf "  $(YELLOW)또는 단계별 설치:$(NC)\n"
	@echo "     a. make iso-mount"
	@echo "     b. make iso-setup-repo"
	@echo "     c. make offline-install"
	@echo "     d. make init"
	@echo "     e. make enable-start"
	@echo "     f. make setup-external"
	@echo ""
	@printf "  $(YELLOW)5. 설치 확인$(NC)\n"
	@echo "     make test"
	@echo ""
	@echo ""
	@printf "$(GREEN)[ 추가 옵션 ]$(NC)\n"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@printf "  $(YELLOW)Apache 오프라인 패키징$(NC)\n"
	@echo "     make apache-offline-package"
	@echo ""
	@printf "  $(YELLOW)Tomcat 오프라인 패키징$(NC)\n"
	@echo "     make tomcat-offline-package"
	@echo ""
	@printf "  $(YELLOW)전체 웹 스택 오프라인 패키징$(NC)\n"
	@echo "     make web-offline-package"
	@echo ""

# ===================================================================
# 오프라인 설치 (인터넷이 없는 서버에서 실행)
# ===================================================================

offline-setup-repo: ## 오프라인 Repository 설정 (압축 해제 후 사용)
	@printf "$(BLUE)오프라인 Repository 설정...$(NC)\n"

	@if [ ! -d "$(OFFLINE_REPO_DIR)/rpms" ]; then \
		printf "$(RED)오류: $(OFFLINE_REPO_DIR)/rpms 디렉토리가 없습니다.$(NC)\n"; \
		printf "$(YELLOW)먼저 오프라인 패키지를 압축 해제하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1. createrepo_c 설치$(NC)\n"
	@cd $(OFFLINE_REPO_DIR)/rpms && sudo rpm -ivh createrepo_c-*.rpm --force --nodeps 2>/dev/null || true

	@printf "$(YELLOW)2. Local repository 설정 파일 생성$(NC)\n"
	@echo "[postgresql-local]" | sudo tee /etc/yum.repos.d/postgresql-local.repo
	@echo "name=PostgreSQL Local Repository" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo
	@echo "baseurl=file://$(OFFLINE_REPO_DIR)/rpms" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo
	@echo "enabled=1" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo
	@echo "gpgcheck=0" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo

	@printf "$(YELLOW)3. Repository 캐시 업데이트$(NC)\n"
	@sudo dnf clean all
	@sudo dnf makecache

	@printf "$(GREEN)✓ 오프라인 Repository 설정 완료$(NC)\n"
	@echo ""
	@printf "$(BLUE)다음 명령어로 설치를 진행하세요:$(NC)\n"
	@printf "  $(YELLOW)make install init enable-start$(NC)\n"

# 오프라인 전용 설치 (온라인 저장소 사용 안함)
offline-install-pkg: ## 오프라인 패키지로 PostgreSQL 설치 (저장소 접근 없음)
	@printf "$(BLUE)PostgreSQL $(PG_VERSION) 오프라인 설치...$(NC)\n"

	@printf "$(YELLOW)1. 기본 PostgreSQL 모듈 비활성화$(NC)\n"
	sudo dnf -qy module disable postgresql 2>/dev/null || true

	@printf "$(YELLOW)2. PostgreSQL $(PG_VERSION) 서버 설치$(NC)\n"
	sudo dnf install -y --disablerepo='*' --enablerepo='postgresql-local' \
		postgresql$(PG_VERSION)-server postgresql$(PG_VERSION)-contrib

	@printf "$(GREEN)✓ PostgreSQL $(PG_VERSION) 오프라인 설치 완료$(NC)\n"

offline-install: offline-setup-repo offline-install-pkg ## 오프라인 패키지를 사용하여 PostgreSQL 설치
	@printf "$(GREEN)✓ 오프라인 설치 완료$(NC)\n"
	@echo ""
	@printf "$(BLUE)다음 단계:$(NC)\n"
	@printf "  $(YELLOW)make init enable-start setup-external$(NC)\n"

# ===================================================================
# ISO + 오프라인 패키지 통합 설치 (오프라인 서버용)
# ===================================================================

offline-full-install: check-env ## ISO + 오프라인 패키지로 전체 설치
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)PostgreSQL 오프라인 전체 설치 시작$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""

	@if [ -z "$(ISO_FILE)" ]; then \
		printf "$(RED)오류: .env 파일에 ISO_FILE이 설정되지 않았습니다.$(NC)\n"; \
		printf "$(YELLOW).env 파일을 편집하여 ISO_FILE 경로를 설정하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1단계: ISO 마운트 및 Repository 설정$(NC)\n"
	$(MAKE) iso-mount
	$(MAKE) iso-setup-repo

	@echo ""
	@printf "$(YELLOW)2단계: 오프라인 PostgreSQL Repository 설정$(NC)\n"
	$(MAKE) offline-setup-repo

	@echo ""
	@printf "$(YELLOW)3단계: PostgreSQL 설치$(NC)\n"
	$(MAKE) offline-install-pkg

	@echo ""
	@printf "$(YELLOW)4단계: 데이터베이스 초기화$(NC)\n"
	$(MAKE) init

	@echo ""
	@printf "$(YELLOW)5단계: 서비스 활성화 및 시작$(NC)\n"
	$(MAKE) enable-start

	@echo ""
	@printf "$(YELLOW)6단계: 외부 접속 설정$(NC)\n"
	$(MAKE) setup-external

	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)PostgreSQL $(PG_VERSION) 오프라인 설치 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)설치된 서비스:$(NC)\n"
	@echo "  PostgreSQL: localhost:$(PG_PORT)"
	@echo ""
	@printf "$(YELLOW)다음 명령어로 테스트하세요:$(NC)\n"
	@printf "  $(YELLOW)make test$(NC)\n"

# ===================================================================
# ISO 로컬 Repository 설정
# ===================================================================

iso-mount: ## RHEL/Rocky Linux ISO 마운트
	@printf "$(BLUE)ISO 파일 마운트...$(NC)\n"
	@if [ -z "$(ISO_FILE)" ]; then \
		printf "$(RED)오류: ISO_FILE 변수가 설정되지 않았습니다.$(NC)\n"; \
		printf "$(YELLOW)사용법: make iso-mount ISO_FILE=/path/to/rhel.iso$(NC)\n"; \
		exit 1; \
	fi

	@if [ ! -f "$(ISO_FILE)" ]; then \
		printf "$(RED)오류: ISO 파일이 존재하지 않습니다: $(ISO_FILE)$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1. 마운트 포인트 생성$(NC)\n"
	@sudo mkdir -p /mnt/rhel-iso

	@printf "$(YELLOW)2. ISO 마운트$(NC)\n"
	@sudo mount -o loop $(ISO_FILE) /mnt/rhel-iso

	@printf "$(GREEN)✓ ISO 마운트 완료: /mnt/rhel-iso$(NC)\n"
	@df -h | grep rhel-iso

iso-setup-repo: ## ISO 기반 로컬 Repository 설정
	@printf "$(BLUE)ISO 기반 로컬 Repository 설정...$(NC)\n"

	@if ! mountpoint -q /mnt/rhel-iso; then \
		printf "$(RED)오류: /mnt/rhel-iso가 마운트되지 않았습니다.$(NC)\n"; \
		printf "$(YELLOW)먼저 'make iso-mount ISO_FILE=/path/to/rhel.iso'를 실행하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1. Repository 설정 파일 생성$(NC)\n"
	@echo "[LocalRepo-BaseOS]" | sudo tee /etc/yum.repos.d/local-iso.repo
	@echo "name=Red Hat Enterprise Linux $(EL_VERSION) BaseOS (Local ISO)" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "baseurl=file:///mnt/rhel-iso/BaseOS" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "enabled=1" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "gpgcheck=1" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "[LocalRepo-AppStream]" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "name=Red Hat Enterprise Linux $(EL_VERSION) AppStream (Local ISO)" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "baseurl=file:///mnt/rhel-iso/AppStream" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "enabled=1" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "gpgcheck=1" | sudo tee -a /etc/yum.repos.d/local-iso.repo
	@echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" | sudo tee -a /etc/yum.repos.d/local-iso.repo

	@printf "$(YELLOW)2. GPG 키 복사$(NC)\n"
	@sudo cp /mnt/rhel-iso/RPM-GPG-KEY-redhat-release /etc/pki/rpm-gpg/ 2>/dev/null || true

	@printf "$(YELLOW)3. Repository 캐시 업데이트$(NC)\n"
	@sudo dnf clean all
	@sudo dnf repolist

	@printf "$(GREEN)✓ ISO Repository 설정 완료$(NC)\n"

iso-unmount: ## ISO 마운트 해제
	@printf "$(BLUE)ISO 마운트 해제...$(NC)\n"
	@sudo umount /mnt/rhel-iso 2>/dev/null || true
	@printf "$(GREEN)✓ ISO 마운트 해제 완료$(NC)\n"

iso-all: iso-setup-repo ## ISO 마운트 및 Repository 설정 (ISO_FILE 필요)
	@printf "$(GREEN)✓ ISO Repository 설정 완료$(NC)\n"
# ===================================================================
# Apache Web Server 설치 및 관리
# ===================================================================

# Apache 기본값 설정
INSTALL_APACHE ?= false
APACHE_HTTP_PORT ?= 80
APACHE_HTTPS_PORT ?= 443
APACHE_SERVICE_NAME ?= httpd
APACHE_CONF_DIR ?= /etc/httpd/conf
APACHE_CONF_D_DIR ?= /etc/httpd/conf.d
APACHE_DOC_ROOT ?= /var/www/html
APACHE_USER ?= apache

apache-install: ## Apache Web Server 설치
	@printf "$(BLUE)Apache Web Server 설치...$(NC)\n"

	@printf "$(YELLOW)1. Apache 패키지 설치$(NC)\n"
	sudo dnf install -y httpd httpd-tools mod_ssl

	@printf "$(YELLOW)2. Apache 사용자 확인$(NC)\n"
	@id $(APACHE_USER) &>/dev/null || printf "$(YELLOW)Apache 사용자가 자동으로 생성됩니다.$(NC)\n"

	@printf "$(GREEN)✓ Apache 설치 완료$(NC)\n"

apache-configure: ## Apache 기본 설정
	@printf "$(BLUE)Apache 기본 설정...$(NC)\n"

	@printf "$(YELLOW)1. ServerName 설정$(NC)\n"
	@if ! grep -q "^ServerName" $(APACHE_CONF_DIR)/httpd.conf; then \
		echo "ServerName localhost" | sudo tee -a $(APACHE_CONF_DIR)/httpd.conf > /dev/null; \
	fi

	@printf "$(YELLOW)2. 포트 설정 확인$(NC)\n"
	@grep "^Listen" $(APACHE_CONF_DIR)/httpd.conf || echo "Listen $(APACHE_HTTP_PORT)"

	@printf "$(YELLOW)3. 테스트 페이지 생성$(NC)\n"
	@echo "<html><head><title>Apache Test</title></head><body><h1>Apache is working!</h1><p>Server: $$(hostname)</p></body></html>" | sudo tee $(APACHE_DOC_ROOT)/index.html > /dev/null

	@printf "$(GREEN)✓ Apache 설정 완료$(NC)\n"

apache-firewall: ## Apache 방화벽 설정
	@printf "$(BLUE)Apache 방화벽 설정...$(NC)\n"

	@if [ "$(ENABLE_FIREWALL)" = "true" ]; then \
		sudo firewall-cmd --permanent --add-service=http; \
		sudo firewall-cmd --permanent --add-service=https; \
		sudo firewall-cmd --reload; \
		printf "$(GREEN)✓ 방화벽 설정 완료 (HTTP, HTTPS)$(NC)\n"; \
	else \
		printf "$(YELLOW)방화벽 설정 건너뜀$(NC)\n"; \
	fi

apache-start: ## Apache 서비스 시작
	@printf "$(BLUE)Apache 서비스 시작...$(NC)\n"
	sudo systemctl start $(APACHE_SERVICE_NAME)
	@printf "$(GREEN)✓ Apache 시작 완료$(NC)\n"

apache-stop: ## Apache 서비스 중지
	@printf "$(BLUE)Apache 서비스 중지...$(NC)\n"
	sudo systemctl stop $(APACHE_SERVICE_NAME)
	@printf "$(GREEN)✓ Apache 중지 완료$(NC)\n"

apache-restart: ## Apache 서비스 재시작
	@printf "$(BLUE)Apache 서비스 재시작...$(NC)\n"
	sudo systemctl restart $(APACHE_SERVICE_NAME)
	@printf "$(GREEN)✓ Apache 재시작 완료$(NC)\n"

apache-status: ## Apache 서비스 상태 확인
	@sudo systemctl status $(APACHE_SERVICE_NAME) --no-pager

apache-enable: ## Apache 자동 시작 활성화
	@printf "$(BLUE)Apache 자동 시작 활성화...$(NC)\n"
	sudo systemctl enable $(APACHE_SERVICE_NAME)
	@printf "$(GREEN)✓ Apache 자동 시작 활성화 완료$(NC)\n"

apache-disable: ## Apache 자동 시작 비활성화
	@printf "$(BLUE)Apache 자동 시작 비활성화...$(NC)\n"
	sudo systemctl disable $(APACHE_SERVICE_NAME)
	@printf "$(GREEN)✓ Apache 자동 시작 비활성화 완료$(NC)\n"

apache-test: ## Apache 동작 테스트
	@printf "$(BLUE)Apache 동작 테스트...$(NC)\n"

	@printf "$(YELLOW)1. 서비스 상태 확인$(NC)\n"
	@systemctl is-active $(APACHE_SERVICE_NAME) &>/dev/null && echo "  ✓ Apache 서비스 실행 중" || (echo "  ✗ Apache 서비스 중지됨" && exit 1)

	@printf "$(YELLOW)2. 포트 리스닝 확인$(NC)\n"
	@ss -tlnp | grep :$(APACHE_HTTP_PORT) &>/dev/null && echo "  ✓ 포트 $(APACHE_HTTP_PORT) 리스닝 중" || echo "  ✗ 포트 리스닝 없음"

	@printf "$(YELLOW)3. HTTP 요청 테스트$(NC)\n"
	@curl -s http://localhost:$(APACHE_HTTP_PORT) | grep -q "Apache is working" && echo "  ✓ HTTP 응답 정상" || echo "  ✗ HTTP 응답 실패"

	@printf "$(GREEN)✓ Apache 테스트 완료$(NC)\n"

apache-all: apache-install apache-configure apache-firewall apache-enable apache-start apache-test ## Apache 전체 설치 및 설정
	@printf "$(GREEN)✓ Apache 설치 및 설정 완료$(NC)\n"

apache-uninstall: apache-stop apache-disable ## Apache 제거
	@printf "$(BLUE)Apache 제거...$(NC)\n"
	sudo dnf remove -y httpd httpd-tools mod_ssl
	@printf "$(GREEN)✓ Apache 제거 완료$(NC)\n"

# ===================================================================
# Apache 오프라인 패키징
# ===================================================================

apache-offline-download: ## Apache RPM 패키지 다운로드
	@printf "$(BLUE)Apache 오프라인 패키지 다운로드...$(NC)\n"

	@mkdir -p $(OFFLINE_REPO_DIR)/apache-rpms

	@printf "$(YELLOW)Apache 패키지 다운로드$(NC)\n"
	@cd $(OFFLINE_REPO_DIR)/apache-rpms && dnf download --resolve --alldeps httpd httpd-tools mod_ssl

	@printf "$(GREEN)✓ Apache 패키지 다운로드 완료$(NC)\n"
	@ls $(OFFLINE_REPO_DIR)/apache-rpms/*.rpm 2>/dev/null | wc -l | xargs echo "  총 RPM 파일 수:"

apache-offline-package: apache-offline-download ## Apache 오프라인 패키지 생성
	@printf "$(BLUE)Apache 오프라인 패키지 생성...$(NC)\n"

	@createrepo_c $(OFFLINE_REPO_DIR)/apache-rpms/
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf apache-offline-el$(EL_VERSION).tar.gz $(notdir $(OFFLINE_REPO_DIR))/apache-rpms

	@printf "$(GREEN)✓ Apache 오프라인 패키지 생성 완료$(NC)\n"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))apache-offline-el$(EL_VERSION).tar.gz 2>/dev/null || true

# ===================================================================
# Tomcat 설치 및 관리
# ===================================================================

# Tomcat 기본값 설정
INSTALL_TOMCAT ?= false
TOMCAT_MAJOR_VERSION ?= 9
TOMCAT_HTTP_PORT ?= 8080
TOMCAT_HTTPS_PORT ?= 8443
TOMCAT_AJP_PORT ?= 8009
TOMCAT_SHUTDOWN_PORT ?= 8005
TOMCAT_INSTALL_METHOD ?= package
TOMCAT_SERVICE_NAME ?= tomcat
TOMCAT_BASE ?= /var/lib/tomcat
TOMCAT_CONF_DIR ?= /etc/tomcat
TOMCAT_USER ?= tomcat
JAVA_HOME ?= /usr/lib/jvm/java-11-openjdk

tomcat-install: ## Tomcat 설치
	@printf "$(BLUE)Tomcat 설치...$(NC)\n"

	@printf "$(YELLOW)1. Java 설치$(NC)\n"
	sudo dnf install -y java-11-openjdk java-11-openjdk-devel

	@printf "$(YELLOW)2. Tomcat 패키지 설치$(NC)\n"
	sudo dnf install -y tomcat tomcat-webapps tomcat-admin-webapps

	@printf "$(YELLOW)3. Java 환경 변수 설정$(NC)\n"
	@echo "JAVA_HOME=$(JAVA_HOME)" | sudo tee /etc/profile.d/java.sh > /dev/null
	@source /etc/profile.d/java.sh 2>/dev/null || true

	@printf "$(GREEN)✓ Tomcat 설치 완료$(NC)\n"

tomcat-configure: ## Tomcat 기본 설정
	@printf "$(BLUE)Tomcat 기본 설정...$(NC)\n"

	@printf "$(YELLOW)1. server.xml 백업$(NC)\n"
	@sudo cp $(TOMCAT_CONF_DIR)/server.xml $(TOMCAT_CONF_DIR)/server.xml.backup 2>/dev/null || true

	@printf "$(YELLOW)2. 포트 설정 확인$(NC)\n"
	@grep "port=\"$(TOMCAT_HTTP_PORT)\"" $(TOMCAT_CONF_DIR)/server.xml &>/dev/null && echo "  ✓ HTTP 포트: $(TOMCAT_HTTP_PORT)" || echo "  ! 포트 설정 필요"

	@printf "$(YELLOW)3. 관리자 계정 설정 (tomcat-users.xml)$(NC)\n"
	@if ! grep -q "<role rolename=\"manager-gui\"/>" $(TOMCAT_CONF_DIR)/tomcat-users.xml 2>/dev/null; then \
		sudo sed -i '/<\/tomcat-users>/i \  <role rolename="manager-gui"/>\n  <role rolename="admin-gui"/>\n  <user username="admin" password="admin" roles="manager-gui,admin-gui"/>' $(TOMCAT_CONF_DIR)/tomcat-users.xml 2>/dev/null || true; \
		echo "  ✓ 관리자 계정 추가 (admin/admin)"; \
	else \
		echo "  ✓ 관리자 계정 이미 존재"; \
	fi

	@printf "$(YELLOW)4. 테스트 웹앱 배포$(NC)\n"
	@echo "<html><head><title>Tomcat Test</title></head><body><h1>Tomcat is working!</h1><p>Server: $$(hostname)</p></body></html>" | sudo tee $(TOMCAT_BASE)/webapps/ROOT/index.html > /dev/null 2>&1 || true

	@printf "$(GREEN)✓ Tomcat 설정 완료$(NC)\n"

tomcat-firewall: ## Tomcat 방화벽 설정
	@printf "$(BLUE)Tomcat 방화벽 설정...$(NC)\n"

	@if [ "$(ENABLE_FIREWALL)" = "true" ]; then \
		sudo firewall-cmd --permanent --add-port=$(TOMCAT_HTTP_PORT)/tcp; \
		sudo firewall-cmd --reload; \
		printf "$(GREEN)✓ 방화벽 설정 완료 (포트 $(TOMCAT_HTTP_PORT))$(NC)\n"; \
	else \
		printf "$(YELLOW)방화벽 설정 건너뜀$(NC)\n"; \
	fi

tomcat-start: ## Tomcat 서비스 시작
	@printf "$(BLUE)Tomcat 서비스 시작...$(NC)\n"
	sudo systemctl start $(TOMCAT_SERVICE_NAME)
	@printf "$(GREEN)✓ Tomcat 시작 완료$(NC)\n"

tomcat-stop: ## Tomcat 서비스 중지
	@printf "$(BLUE)Tomcat 서비스 중지...$(NC)\n"
	sudo systemctl stop $(TOMCAT_SERVICE_NAME)
	@printf "$(GREEN)✓ Tomcat 중지 완료$(NC)\n"

tomcat-restart: ## Tomcat 서비스 재시작
	@printf "$(BLUE)Tomcat 서비스 재시작...$(NC)\n"
	sudo systemctl restart $(TOMCAT_SERVICE_NAME)
	@printf "$(GREEN)✓ Tomcat 재시작 완료$(NC)\n"

tomcat-status: ## Tomcat 서비스 상태 확인
	@sudo systemctl status $(TOMCAT_SERVICE_NAME) --no-pager

tomcat-enable: ## Tomcat 자동 시작 활성화
	@printf "$(BLUE)Tomcat 자동 시작 활성화...$(NC)\n"
	sudo systemctl enable $(TOMCAT_SERVICE_NAME)
	@printf "$(GREEN)✓ Tomcat 자동 시작 활성화 완료$(NC)\n"

tomcat-disable: ## Tomcat 자동 시작 비활성화
	@printf "$(BLUE)Tomcat 자동 시작 비활성화...$(NC)\n"
	sudo systemctl disable $(TOMCAT_SERVICE_NAME)
	@printf "$(GREEN)✓ Tomcat 자동 시작 비활성화 완료$(NC)\n"

tomcat-test: ## Tomcat 동작 테스트
	@printf "$(BLUE)Tomcat 동작 테스트...$(NC)\n"

	@printf "$(YELLOW)1. 서비스 상태 확인$(NC)\n"
	@systemctl is-active $(TOMCAT_SERVICE_NAME) &>/dev/null && echo "  ✓ Tomcat 서비스 실행 중" || (echo "  ✗ Tomcat 서비스 중지됨" && exit 1)

	@printf "$(YELLOW)2. 포트 리스닝 확인$(NC)\n"
	@ss -tlnp | grep :$(TOMCAT_HTTP_PORT) &>/dev/null && echo "  ✓ 포트 $(TOMCAT_HTTP_PORT) 리스닝 중" || echo "  ✗ 포트 리스닝 없음"

	@printf "$(YELLOW)3. HTTP 요청 테스트$(NC)\n"
	@curl -s http://localhost:$(TOMCAT_HTTP_PORT) | grep -q "Tomcat" && echo "  ✓ HTTP 응답 정상" || echo "  ✗ HTTP 응답 실패"

	@printf "$(YELLOW)4. Java 버전 확인$(NC)\n"
	@java -version 2>&1 | head -1

	@printf "$(GREEN)✓ Tomcat 테스트 완료$(NC)\n"

tomcat-all: tomcat-install tomcat-configure tomcat-firewall tomcat-enable tomcat-start tomcat-test ## Tomcat 전체 설치 및 설정
	@printf "$(GREEN)✓ Tomcat 설치 및 설정 완료$(NC)\n"

tomcat-uninstall: tomcat-stop tomcat-disable ## Tomcat 제거
	@printf "$(BLUE)Tomcat 제거...$(NC)\n"
	sudo dnf remove -y tomcat tomcat-webapps tomcat-admin-webapps
	@printf "$(GREEN)✓ Tomcat 제거 완료$(NC)\n"

tomcat-logs: ## Tomcat 로그 확인
	@printf "$(BLUE)Tomcat 로그 확인...$(NC)\n"
	sudo journalctl -u $(TOMCAT_SERVICE_NAME) -f

# ===================================================================
# Tomcat 오프라인 패키징
# ===================================================================

# Tomcat 오프라인 패키지 파일명
TOMCAT_OFFLINE_ARCHIVE_NAME ?= tomcat-offline-el$(EL_VERSION).tar.gz

tomcat-offline-download: ## Tomcat RPM 패키지 다운로드 (ISO repo 필요)
	@printf "$(BLUE)Tomcat 오프라인 패키지 다운로드...$(NC)\n"

	@mkdir -p $(OFFLINE_REPO_DIR)/tomcat-rpms

	@printf "$(YELLOW)1. createrepo 도구 다운로드$(NC)\n"
	@cd $(OFFLINE_REPO_DIR)/tomcat-rpms && dnf download --resolve createrepo_c 2>/dev/null || true

	@printf "$(YELLOW)2. Tomcat 및 Java 패키지 다운로드$(NC)\n"
	@cd $(OFFLINE_REPO_DIR)/tomcat-rpms && dnf download --resolve --alldeps \
		java-11-openjdk java-11-openjdk-devel \
		tomcat tomcat-webapps tomcat-admin-webapps

	@printf "$(GREEN)✓ Tomcat 패키지 다운로드 완료$(NC)\n"
	@ls $(OFFLINE_REPO_DIR)/tomcat-rpms/*.rpm 2>/dev/null | wc -l | xargs echo "  총 RPM 파일 수:"

tomcat-offline-createrepo: ## Tomcat repository 메타데이터 생성
	@printf "$(BLUE)Tomcat Repository 메타데이터 생성...$(NC)\n"

	@if ! command -v createrepo_c &> /dev/null; then \
		printf "$(YELLOW)createrepo_c 설치 중...$(NC)\n"; \
		sudo dnf install -y createrepo_c; \
	fi

	@createrepo_c $(OFFLINE_REPO_DIR)/tomcat-rpms/

	@printf "$(GREEN)✓ Tomcat Repository 메타데이터 생성 완료$(NC)\n"

tomcat-offline-package: tomcat-offline-download tomcat-offline-createrepo ## Tomcat 오프라인 패키지 생성
	@printf "$(BLUE)Tomcat 오프라인 패키지 압축...$(NC)\n"

	@printf "$(YELLOW)1. 설치 스크립트 복사$(NC)\n"
	@cp -f scripts/offline-setup-repo.sh $(OFFLINE_REPO_DIR)/ 2>/dev/null || true
	@chmod +x $(OFFLINE_REPO_DIR)/offline-setup-repo.sh 2>/dev/null || true

	@printf "$(YELLOW)2. README 파일 생성$(NC)\n"
	@echo "Tomcat $(TOMCAT_MAJOR_VERSION) 오프라인 설치 패키지" > $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "========================================" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "## 오프라인 서버 설치 방법" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "1. 압축 해제:" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "   tar -xzf $(TOMCAT_OFFLINE_ARCHIVE_NAME)" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "2. 전체 설치 (권장):" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "   make tomcat-offline-full-install" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt

	@printf "$(YELLOW)3. 압축 파일 생성$(NC)\n"
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf $(TOMCAT_OFFLINE_ARCHIVE_NAME) $(notdir $(OFFLINE_REPO_DIR))/tomcat-rpms

	@printf "$(GREEN)✓ Tomcat 오프라인 패키지 생성 완료$(NC)\n"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))$(TOMCAT_OFFLINE_ARCHIVE_NAME) 2>/dev/null || true

# ===================================================================
# Tomcat 오프라인 패키지 생성 전체 플로우 (온라인 서버용)
# ===================================================================

tomcat-offline-package-all: check-env ## [온라인] ISO 기반 Tomcat 오프라인 패키지 생성
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)Tomcat 오프라인 패키지 생성 시작 (ISO 기반)$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""

	@if [ -z "$(ISO_FILE)" ]; then \
		printf "$(RED)오류: .env 파일에 ISO_FILE이 설정되지 않았습니다.$(NC)\n"; \
		printf "$(YELLOW).env 파일을 편집하여 ISO_FILE 경로를 설정하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1단계: ISO 마운트 및 로컬 Repository 설정$(NC)\n"
	$(MAKE) iso-mount
	$(MAKE) iso-setup-repo

	@echo ""
	@printf "$(YELLOW)2단계: Tomcat 및 Java 패키지 다운로드$(NC)\n"
	$(MAKE) tomcat-offline-download

	@echo ""
	@printf "$(YELLOW)3단계: Repository 메타데이터 생성$(NC)\n"
	$(MAKE) tomcat-offline-createrepo

	@echo ""
	@printf "$(YELLOW)4단계: 오프라인 패키지 압축$(NC)\n"
	@printf "$(YELLOW)4-1. 설치 스크립트 복사$(NC)\n"
	@cp -f scripts/offline-setup-repo.sh $(OFFLINE_REPO_DIR)/ 2>/dev/null || true
	@chmod +x $(OFFLINE_REPO_DIR)/offline-setup-repo.sh 2>/dev/null || true

	@printf "$(YELLOW)4-2. README 파일 생성$(NC)\n"
	@echo "Tomcat $(TOMCAT_MAJOR_VERSION) 오프라인 설치 패키지" > $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "========================================" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "## 오프라인 서버 설치 방법" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "1. 패키지 파일과 ISO 파일을 오프라인 서버로 복사" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "2. 압축 해제:" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "   tar -xzf $(TOMCAT_OFFLINE_ARCHIVE_NAME)" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "3. .env 파일에서 ISO_FILE 경로 설정" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "4. 전체 설치 (권장):" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt
	@echo "   make tomcat-offline-full-install" >> $(OFFLINE_REPO_DIR)/tomcat-rpms/README.txt

	@printf "$(YELLOW)4-3. 압축 파일 생성$(NC)\n"
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf $(TOMCAT_OFFLINE_ARCHIVE_NAME) $(notdir $(OFFLINE_REPO_DIR))/tomcat-rpms

	@echo ""
	@printf "$(YELLOW)5단계: ISO 마운트 해제$(NC)\n"
	$(MAKE) iso-unmount

	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)Tomcat 오프라인 패키지 생성 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)생성된 파일:$(NC)\n"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))$(TOMCAT_OFFLINE_ARCHIVE_NAME) 2>/dev/null || true
	@echo ""
	@printf "$(YELLOW)오프라인 서버에서 설치 방법:$(NC)\n"
	@echo "  1. 패키지, ISO 파일, 프로젝트 디렉토리를 오프라인 서버로 복사"
	@echo "  2. 압축 해제: tar -xzf $(TOMCAT_OFFLINE_ARCHIVE_NAME) -C /root/"
	@echo "  3. .env 파일에서 ISO_FILE 경로 설정"
	@echo "  4. 설치 실행: make tomcat-offline-full-install"

# ===================================================================
# Tomcat 오프라인 설치 (오프라인 서버용)
# ===================================================================

tomcat-offline-setup-repo: ## Tomcat 오프라인 Repository 설정
	@printf "$(BLUE)Tomcat 오프라인 Repository 설정...$(NC)\n"

	@if [ ! -d "$(OFFLINE_REPO_DIR)/tomcat-rpms" ]; then \
		printf "$(RED)오류: $(OFFLINE_REPO_DIR)/tomcat-rpms 디렉토리가 없습니다.$(NC)\n"; \
		printf "$(YELLOW)먼저 Tomcat 오프라인 패키지를 압축 해제하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1. createrepo_c 설치$(NC)\n"
	@cd $(OFFLINE_REPO_DIR)/tomcat-rpms && sudo rpm -ivh createrepo_c-*.rpm --force --nodeps 2>/dev/null || true

	@printf "$(YELLOW)2. Local repository 설정 파일 생성$(NC)\n"
	@echo "[tomcat-local]" | sudo tee /etc/yum.repos.d/tomcat-local.repo
	@echo "name=Tomcat Local Repository" | sudo tee -a /etc/yum.repos.d/tomcat-local.repo
	@echo "baseurl=file://$(OFFLINE_REPO_DIR)/tomcat-rpms" | sudo tee -a /etc/yum.repos.d/tomcat-local.repo
	@echo "enabled=1" | sudo tee -a /etc/yum.repos.d/tomcat-local.repo
	@echo "gpgcheck=0" | sudo tee -a /etc/yum.repos.d/tomcat-local.repo

	@printf "$(YELLOW)3. Repository 캐시 업데이트$(NC)\n"
	@sudo dnf clean all
	@sudo dnf makecache

	@printf "$(GREEN)✓ Tomcat 오프라인 Repository 설정 완료$(NC)\n"

tomcat-offline-install-pkg: ## Tomcat 오프라인 설치 (저장소 접근 없음)
	@printf "$(BLUE)Tomcat 오프라인 설치...$(NC)\n"

	@printf "$(YELLOW)1. Java 설치$(NC)\n"
	sudo dnf install -y --disablerepo='*' --enablerepo='tomcat-local,LocalRepo-BaseOS,LocalRepo-AppStream' \
		java-11-openjdk java-11-openjdk-devel

	@printf "$(YELLOW)2. Tomcat 패키지 설치$(NC)\n"
	sudo dnf install -y --disablerepo='*' --enablerepo='tomcat-local,LocalRepo-BaseOS,LocalRepo-AppStream' \
		tomcat tomcat-webapps tomcat-admin-webapps

	@printf "$(YELLOW)3. Java 환경 변수 설정$(NC)\n"
	@echo "JAVA_HOME=$(JAVA_HOME)" | sudo tee /etc/profile.d/java.sh > /dev/null
	@source /etc/profile.d/java.sh 2>/dev/null || true

	@printf "$(GREEN)✓ Tomcat 오프라인 설치 완료$(NC)\n"

tomcat-offline-install: tomcat-offline-setup-repo tomcat-offline-install-pkg ## Tomcat 오프라인 패키지를 사용하여 설치
	@printf "$(GREEN)✓ Tomcat 오프라인 설치 완료$(NC)\n"
	@echo ""
	@printf "$(BLUE)다음 단계:$(NC)\n"
	@printf "  $(YELLOW)make tomcat-configure tomcat-firewall tomcat-enable tomcat-start$(NC)\n"

# ===================================================================
# Tomcat ISO + 오프라인 패키지 통합 설치 (오프라인 서버용)
# ===================================================================

tomcat-offline-full-install: check-env ## ISO + Tomcat 오프라인 패키지로 전체 설치
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)Tomcat 오프라인 전체 설치 시작$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""

	@if [ -z "$(ISO_FILE)" ]; then \
		printf "$(RED)오류: .env 파일에 ISO_FILE이 설정되지 않았습니다.$(NC)\n"; \
		printf "$(YELLOW).env 파일을 편집하여 ISO_FILE 경로를 설정하세요.$(NC)\n"; \
		exit 1; \
	fi

	@printf "$(YELLOW)1단계: ISO 마운트 및 Repository 설정$(NC)\n"
	$(MAKE) iso-mount
	$(MAKE) iso-setup-repo

	@echo ""
	@printf "$(YELLOW)2단계: Tomcat 오프라인 Repository 설정$(NC)\n"
	$(MAKE) tomcat-offline-setup-repo

	@echo ""
	@printf "$(YELLOW)3단계: Tomcat 설치$(NC)\n"
	$(MAKE) tomcat-offline-install-pkg

	@echo ""
	@printf "$(YELLOW)4단계: Tomcat 설정$(NC)\n"
	$(MAKE) tomcat-configure

	@echo ""
	@printf "$(YELLOW)5단계: 방화벽 설정$(NC)\n"
	$(MAKE) tomcat-firewall

	@echo ""
	@printf "$(YELLOW)6단계: 서비스 활성화 및 시작$(NC)\n"
	$(MAKE) tomcat-enable
	$(MAKE) tomcat-start

	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)Tomcat $(TOMCAT_MAJOR_VERSION) 오프라인 설치 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)설치된 서비스:$(NC)\n"
	@echo "  Tomcat: http://localhost:$(TOMCAT_HTTP_PORT)"
	@echo ""
	@printf "$(YELLOW)다음 명령어로 테스트하세요:$(NC)\n"
	@printf "  $(YELLOW)make tomcat-test$(NC)\n"

# ===================================================================
# 통합 웹 스택 설치
# ===================================================================

web-all: apache-all tomcat-all ## Apache + Tomcat 전체 설치
	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)웹 스택 설치 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)설치된 서비스:$(NC)\n"
	@echo "  - Apache HTTP Server: http://localhost:$(APACHE_HTTP_PORT)"
	@echo "  - Tomcat Application Server: http://localhost:$(TOMCAT_HTTP_PORT)"
	@echo ""
	@printf "$(YELLOW)다음 단계:$(NC)\n"
	@echo "  1. Apache 관리자 페이지: http://localhost:$(APACHE_HTTP_PORT)"
	@echo "  2. Tomcat 관리자 페이지: http://localhost:$(TOMCAT_HTTP_PORT)/manager"
	@echo "     (계정: admin/admin)"

web-test: apache-test tomcat-test ## Apache + Tomcat 테스트
	@printf "$(GREEN)✓ 모든 웹 서비스 테스트 통과$(NC)\n"

web-offline-package: apache-offline-package tomcat-offline-package ## Apache + Tomcat 오프라인 패키지 생성
	@printf "$(GREEN)✓ 웹 스택 오프라인 패키지 생성 완료$(NC)\n"

# ===================================================================
# 전체 스택 설치 (PostgreSQL + Apache + Tomcat)
# ===================================================================

stack-all: tune-all install init enable-start setup-external apache-all tomcat-all ## PostgreSQL + Apache + Tomcat 전체 설치
	@echo ""
	@printf "$(GREEN)========================================$(NC)\n"
	@printf "$(GREEN)전체 스택 설치 완료!$(NC)\n"
	@printf "$(GREEN)========================================$(NC)\n"
	@echo ""
	@printf "$(BLUE)설치된 서비스:$(NC)\n"
	@echo "  - PostgreSQL: localhost:$(PG_PORT)"
	@echo "  - Apache: http://localhost:$(APACHE_HTTP_PORT)"
	@echo "  - Tomcat: http://localhost:$(TOMCAT_HTTP_PORT)"

stack-test: test apache-test tomcat-test ## 전체 스택 테스트
	@printf "$(GREEN)✓ 전체 스택 테스트 통과$(NC)\n"

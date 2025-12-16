# ===================================================================
# 테스트 및 검증
# ===================================================================

test-connection: ## PostgreSQL 연결 테스트
	@echo "$(BLUE)PostgreSQL 연결 테스트...$(NC)"
	@sudo -u $(PG_OS_USER) psql -c "SELECT version();" || (echo "$(RED)연결 실패$(NC)" && exit 1)
	@echo "$(GREEN)✓ 연결 테스트 성공$(NC)"

test-database: ## 데이터베이스 생성/삭제 테스트
	@echo "$(BLUE)데이터베이스 CRUD 테스트...$(NC)"

	@echo "$(YELLOW)1. 테스트 테이블 생성$(NC)"
	@sudo -u $(PG_OS_USER) psql -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(100), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

	@echo "$(YELLOW)2. 데이터 삽입$(NC)"
	@sudo -u $(PG_OS_USER) psql -c "INSERT INTO test_table (name) VALUES ('Test Data 1'), ('Test Data 2'), ('Test Data 3');"

	@echo "$(YELLOW)3. 데이터 조회$(NC)"
	@sudo -u $(PG_OS_USER) psql -c "SELECT * FROM test_table;"

	@echo "$(YELLOW)4. 데이터 개수 확인$(NC)"
	@sudo -u $(PG_OS_USER) psql -t -c "SELECT COUNT(*) FROM test_table;" | xargs echo "레코드 수:"

	@echo "$(YELLOW)5. 테이블 삭제$(NC)"
	@sudo -u $(PG_OS_USER) psql -c "DROP TABLE IF EXISTS test_table;"

	@echo "$(GREEN)✓ 데이터베이스 테스트 완료$(NC)"

test-performance: ## 간단한 성능 테스트 (pgbench)
	@echo "$(BLUE)PostgreSQL 성능 테스트...$(NC)"

	@echo "$(YELLOW)1. pgbench 테스트 DB 생성$(NC)"
	@sudo -u $(PG_OS_USER) createdb -O $(PG_OS_USER) pgbench_test 2>/dev/null || true

	@echo "$(YELLOW)2. pgbench 초기화 (scale=10)$(NC)"
	@sudo -u $(PG_OS_USER) pgbench -i -s 10 pgbench_test

	@echo "$(YELLOW)3. 성능 테스트 실행 (10 clients, 1000 transactions)$(NC)"
	@sudo -u $(PG_OS_USER) pgbench -c 10 -j 2 -t 1000 pgbench_test

	@echo "$(YELLOW)4. 테스트 DB 삭제$(NC)"
	@sudo -u $(PG_OS_USER) dropdb pgbench_test

	@echo "$(GREEN)✓ 성능 테스트 완료$(NC)"

test: test-connection test-database ## 전체 테스트 실행 (연결 + 데이터베이스)
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)모든 테스트 통과!$(NC)"
	@echo "$(GREEN)========================================$(NC)"

# ===================================================================
# 오프라인 패키징 (인터넷 연결된 서버에서 실행)
# ===================================================================

offline-download: ## PostgreSQL RPM 패키지 다운로드
	@echo "$(BLUE)PostgreSQL 오프라인 패키지 다운로드...$(NC)"

	@echo "$(YELLOW)1. 다운로드 디렉토리 생성$(NC)"
	@mkdir -p $(OFFLINE_REPO_DIR)/rpms

	@echo "$(YELLOW)2. PGDG 저장소 설정 확인$(NC)"
	@if ! dnf repolist | grep -q pgdg$(PG_VERSION); then \
		echo "$(YELLOW)PGDG 저장소 추가 중...$(NC)"; \
		sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(EL_VERSION)-x86_64/pgdg-redhat-repo-latest.noarch.rpm; \
		sudo dnf -qy module disable postgresql; \
	fi

	@echo "$(YELLOW)3. PostgreSQL 패키지 다운로드$(NC)"
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

	@echo "$(YELLOW)4. createrepo 도구 다운로드$(NC)"
	@cd $(OFFLINE_REPO_DIR)/rpms && dnf download --resolve createrepo_c

	@echo "$(GREEN)✓ 패키지 다운로드 완료$(NC)"
	@echo "$(BLUE)다운로드 위치: $(OFFLINE_REPO_DIR)/rpms$(NC)"
	@ls $(OFFLINE_REPO_DIR)/rpms/*.rpm 2>/dev/null | wc -l | xargs echo "  총 RPM 파일 수:"

offline-createrepo: ## createrepo 실행하여 repository 메타데이터 생성
	@echo "$(BLUE)Repository 메타데이터 생성...$(NC)"

	@if ! command -v createrepo_c &> /dev/null; then \
		echo "$(YELLOW)createrepo_c 설치 중...$(NC)"; \
		sudo dnf install -y createrepo_c; \
	fi

	@echo "$(YELLOW)createrepo 실행$(NC)"
	@createrepo_c $(OFFLINE_REPO_DIR)/rpms/

	@echo "$(GREEN)✓ Repository 메타데이터 생성 완료$(NC)"

offline-package: offline-download offline-createrepo ## 오프라인 패키지 생성 및 압축
	@echo "$(BLUE)오프라인 패키지 압축...$(NC)"

	@echo "$(YELLOW)1. 설치 스크립트 복사$(NC)"
	@cp -f scripts/offline-setup-repo.sh $(OFFLINE_REPO_DIR)/
	@chmod +x $(OFFLINE_REPO_DIR)/offline-setup-repo.sh

	@echo "$(YELLOW)2. README 파일 생성$(NC)"
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

	@echo "$(YELLOW)3. 압축 파일 생성$(NC)"
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf $(OFFLINE_ARCHIVE_NAME) $(notdir $(OFFLINE_REPO_DIR))

	@echo "$(GREEN)✓ 오프라인 패키지 생성 완료$(NC)"
	@echo ""
	@echo "$(BLUE)압축 파일: $(dir $(OFFLINE_REPO_DIR))$(OFFLINE_ARCHIVE_NAME)$(NC)"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))$(OFFLINE_ARCHIVE_NAME) 2>/dev/null || true
	@echo ""
	@echo "$(YELLOW)이 파일을 오프라인 서버로 복사하여 사용하세요.$(NC)"

# ===================================================================
# 오프라인 설치 (인터넷이 없는 서버에서 실행)
# ===================================================================

offline-setup-repo: ## 오프라인 Repository 설정 (압축 해제 후 사용)
	@echo "$(BLUE)오프라인 Repository 설정...$(NC)"

	@if [ ! -d "$(OFFLINE_REPO_DIR)/rpms" ]; then \
		echo "$(RED)오류: $(OFFLINE_REPO_DIR)/rpms 디렉토리가 없습니다.$(NC)"; \
		echo "$(YELLOW)먼저 오프라인 패키지를 압축 해제하세요.$(NC)"; \
		exit 1; \
	fi

	@echo "$(YELLOW)1. createrepo_c 설치$(NC)"
	@cd $(OFFLINE_REPO_DIR)/rpms && sudo rpm -ivh createrepo_c-*.rpm --force --nodeps 2>/dev/null || true

	@echo "$(YELLOW)2. Local repository 설정 파일 생성$(NC)"
	@echo "[postgresql-local]" | sudo tee /etc/yum.repos.d/postgresql-local.repo
	@echo "name=PostgreSQL Local Repository" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo
	@echo "baseurl=file://$(OFFLINE_REPO_DIR)/rpms" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo
	@echo "enabled=1" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo
	@echo "gpgcheck=0" | sudo tee -a /etc/yum.repos.d/postgresql-local.repo

	@echo "$(YELLOW)3. Repository 캐시 업데이트$(NC)"
	@sudo dnf clean all
	@sudo dnf makecache

	@echo "$(GREEN)✓ 오프라인 Repository 설정 완료$(NC)"
	@echo ""
	@echo "$(BLUE)다음 명령어로 설치를 진행하세요:$(NC)"
	@echo "  $(YELLOW)make install init enable-start$(NC)"

offline-install: offline-setup-repo install ## 오프라인 패키지를 사용하여 PostgreSQL 설치
	@echo "$(GREEN)✓ 오프라인 설치 완료$(NC)"

# ===================================================================
# ISO 로컬 Repository 설정
# ===================================================================

iso-mount: ## RHEL/Rocky Linux ISO 마운트
	@echo "$(BLUE)ISO 파일 마운트...$(NC)"
	@if [ -z "$(ISO_FILE)" ]; then \
		echo "$(RED)오류: ISO_FILE 변수가 설정되지 않았습니다.$(NC)"; \
		echo "$(YELLOW)사용법: make iso-mount ISO_FILE=/path/to/rhel.iso$(NC)"; \
		exit 1; \
	fi

	@if [ ! -f "$(ISO_FILE)" ]; then \
		echo "$(RED)오류: ISO 파일이 존재하지 않습니다: $(ISO_FILE)$(NC)"; \
		exit 1; \
	fi

	@echo "$(YELLOW)1. 마운트 포인트 생성$(NC)"
	@sudo mkdir -p /mnt/rhel-iso

	@echo "$(YELLOW)2. ISO 마운트$(NC)"
	@sudo mount -o loop $(ISO_FILE) /mnt/rhel-iso

	@echo "$(GREEN)✓ ISO 마운트 완료: /mnt/rhel-iso$(NC)"
	@df -h | grep rhel-iso

iso-setup-repo: ## ISO 기반 로컬 Repository 설정
	@echo "$(BLUE)ISO 기반 로컬 Repository 설정...$(NC)"

	@if ! mountpoint -q /mnt/rhel-iso; then \
		echo "$(RED)오류: /mnt/rhel-iso가 마운트되지 않았습니다.$(NC)"; \
		echo "$(YELLOW)먼저 'make iso-mount ISO_FILE=/path/to/rhel.iso'를 실행하세요.$(NC)"; \
		exit 1; \
	fi

	@echo "$(YELLOW)1. Repository 설정 파일 생성$(NC)"
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

	@echo "$(YELLOW)2. GPG 키 복사$(NC)"
	@sudo cp /mnt/rhel-iso/RPM-GPG-KEY-redhat-release /etc/pki/rpm-gpg/ 2>/dev/null || true

	@echo "$(YELLOW)3. Repository 캐시 업데이트$(NC)"
	@sudo dnf clean all
	@sudo dnf repolist

	@echo "$(GREEN)✓ ISO Repository 설정 완료$(NC)"

iso-unmount: ## ISO 마운트 해제
	@echo "$(BLUE)ISO 마운트 해제...$(NC)"
	@sudo umount /mnt/rhel-iso 2>/dev/null || true
	@echo "$(GREEN)✓ ISO 마운트 해제 완료$(NC)"

iso-all: iso-setup-repo ## ISO 마운트 및 Repository 설정 (ISO_FILE 필요)
	@echo "$(GREEN)✓ ISO Repository 설정 완료$(NC)"

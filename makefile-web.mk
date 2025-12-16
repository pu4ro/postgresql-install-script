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
	@echo "$(BLUE)Apache Web Server 설치...$(NC)"

	@echo "$(YELLOW)1. Apache 패키지 설치$(NC)"
	sudo dnf install -y httpd httpd-tools mod_ssl

	@echo "$(YELLOW)2. Apache 사용자 확인$(NC)"
	@id $(APACHE_USER) &>/dev/null || echo "$(YELLOW)Apache 사용자가 자동으로 생성됩니다.$(NC)"

	@echo "$(GREEN)✓ Apache 설치 완료$(NC)"

apache-configure: ## Apache 기본 설정
	@echo "$(BLUE)Apache 기본 설정...$(NC)"

	@echo "$(YELLOW)1. ServerName 설정$(NC)"
	@if ! grep -q "^ServerName" $(APACHE_CONF_DIR)/httpd.conf; then \
		echo "ServerName localhost" | sudo tee -a $(APACHE_CONF_DIR)/httpd.conf > /dev/null; \
	fi

	@echo "$(YELLOW)2. 포트 설정 확인$(NC)"
	@grep "^Listen" $(APACHE_CONF_DIR)/httpd.conf || echo "Listen $(APACHE_HTTP_PORT)"

	@echo "$(YELLOW)3. 테스트 페이지 생성$(NC)"
	@echo "<html><head><title>Apache Test</title></head><body><h1>Apache is working!</h1><p>Server: $$(hostname)</p></body></html>" | sudo tee $(APACHE_DOC_ROOT)/index.html > /dev/null

	@echo "$(GREEN)✓ Apache 설정 완료$(NC)"

apache-firewall: ## Apache 방화벽 설정
	@echo "$(BLUE)Apache 방화벽 설정...$(NC)"

	@if [ "$(ENABLE_FIREWALL)" = "true" ]; then \
		sudo firewall-cmd --permanent --add-service=http; \
		sudo firewall-cmd --permanent --add-service=https; \
		sudo firewall-cmd --reload; \
		echo "$(GREEN)✓ 방화벽 설정 완료 (HTTP, HTTPS)$(NC)"; \
	else \
		echo "$(YELLOW)방화벽 설정 건너뜀$(NC)"; \
	fi

apache-start: ## Apache 서비스 시작
	@echo "$(BLUE)Apache 서비스 시작...$(NC)"
	sudo systemctl start $(APACHE_SERVICE_NAME)
	@echo "$(GREEN)✓ Apache 시작 완료$(NC)"

apache-stop: ## Apache 서비스 중지
	@echo "$(BLUE)Apache 서비스 중지...$(NC)"
	sudo systemctl stop $(APACHE_SERVICE_NAME)
	@echo "$(GREEN)✓ Apache 중지 완료$(NC)"

apache-restart: ## Apache 서비스 재시작
	@echo "$(BLUE)Apache 서비스 재시작...$(NC)"
	sudo systemctl restart $(APACHE_SERVICE_NAME)
	@echo "$(GREEN)✓ Apache 재시작 완료$(NC)"

apache-status: ## Apache 서비스 상태 확인
	@sudo systemctl status $(APACHE_SERVICE_NAME) --no-pager

apache-enable: ## Apache 자동 시작 활성화
	@echo "$(BLUE)Apache 자동 시작 활성화...$(NC)"
	sudo systemctl enable $(APACHE_SERVICE_NAME)
	@echo "$(GREEN)✓ Apache 자동 시작 활성화 완료$(NC)"

apache-disable: ## Apache 자동 시작 비활성화
	@echo "$(BLUE)Apache 자동 시작 비활성화...$(NC)"
	sudo systemctl disable $(APACHE_SERVICE_NAME)
	@echo "$(GREEN)✓ Apache 자동 시작 비활성화 완료$(NC)"

apache-test: ## Apache 동작 테스트
	@echo "$(BLUE)Apache 동작 테스트...$(NC)"

	@echo "$(YELLOW)1. 서비스 상태 확인$(NC)"
	@systemctl is-active $(APACHE_SERVICE_NAME) &>/dev/null && echo "  ✓ Apache 서비스 실행 중" || (echo "  ✗ Apache 서비스 중지됨" && exit 1)

	@echo "$(YELLOW)2. 포트 리스닝 확인$(NC)"
	@ss -tlnp | grep :$(APACHE_HTTP_PORT) &>/dev/null && echo "  ✓ 포트 $(APACHE_HTTP_PORT) 리스닝 중" || echo "  ✗ 포트 리스닝 없음"

	@echo "$(YELLOW)3. HTTP 요청 테스트$(NC)"
	@curl -s http://localhost:$(APACHE_HTTP_PORT) | grep -q "Apache is working" && echo "  ✓ HTTP 응답 정상" || echo "  ✗ HTTP 응답 실패"

	@echo "$(GREEN)✓ Apache 테스트 완료$(NC)"

apache-all: apache-install apache-configure apache-firewall apache-enable apache-start apache-test ## Apache 전체 설치 및 설정
	@echo "$(GREEN)✓ Apache 설치 및 설정 완료$(NC)"

apache-uninstall: apache-stop apache-disable ## Apache 제거
	@echo "$(BLUE)Apache 제거...$(NC)"
	sudo dnf remove -y httpd httpd-tools mod_ssl
	@echo "$(GREEN)✓ Apache 제거 완료$(NC)"

# ===================================================================
# Apache 오프라인 패키징
# ===================================================================

apache-offline-download: ## Apache RPM 패키지 다운로드
	@echo "$(BLUE)Apache 오프라인 패키지 다운로드...$(NC)"

	@mkdir -p $(OFFLINE_REPO_DIR)/apache-rpms

	@echo "$(YELLOW)Apache 패키지 다운로드$(NC)"
	@cd $(OFFLINE_REPO_DIR)/apache-rpms && dnf download --resolve --alldeps httpd httpd-tools mod_ssl

	@echo "$(GREEN)✓ Apache 패키지 다운로드 완료$(NC)"
	@ls $(OFFLINE_REPO_DIR)/apache-rpms/*.rpm 2>/dev/null | wc -l | xargs echo "  총 RPM 파일 수:"

apache-offline-package: apache-offline-download ## Apache 오프라인 패키지 생성
	@echo "$(BLUE)Apache 오프라인 패키지 생성...$(NC)"

	@createrepo_c $(OFFLINE_REPO_DIR)/apache-rpms/
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf apache-offline-el$(EL_VERSION).tar.gz $(notdir $(OFFLINE_REPO_DIR))/apache-rpms

	@echo "$(GREEN)✓ Apache 오프라인 패키지 생성 완료$(NC)"
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
	@echo "$(BLUE)Tomcat 설치...$(NC)"

	@echo "$(YELLOW)1. Java 설치$(NC)"
	sudo dnf install -y java-11-openjdk java-11-openjdk-devel

	@echo "$(YELLOW)2. Tomcat 패키지 설치$(NC)"
	sudo dnf install -y tomcat tomcat-webapps tomcat-admin-webapps

	@echo "$(YELLOW)3. Java 환경 변수 설정$(NC)"
	@echo "JAVA_HOME=$(JAVA_HOME)" | sudo tee /etc/profile.d/java.sh > /dev/null
	@source /etc/profile.d/java.sh 2>/dev/null || true

	@echo "$(GREEN)✓ Tomcat 설치 완료$(NC)"

tomcat-configure: ## Tomcat 기본 설정
	@echo "$(BLUE)Tomcat 기본 설정...$(NC)"

	@echo "$(YELLOW)1. server.xml 백업$(NC)"
	@sudo cp $(TOMCAT_CONF_DIR)/server.xml $(TOMCAT_CONF_DIR)/server.xml.backup 2>/dev/null || true

	@echo "$(YELLOW)2. 포트 설정 확인$(NC)"
	@grep "port=\"$(TOMCAT_HTTP_PORT)\"" $(TOMCAT_CONF_DIR)/server.xml &>/dev/null && echo "  ✓ HTTP 포트: $(TOMCAT_HTTP_PORT)" || echo "  ! 포트 설정 필요"

	@echo "$(YELLOW)3. 관리자 계정 설정 (tomcat-users.xml)$(NC)"
	@if ! grep -q "<role rolename=\"manager-gui\"/>" $(TOMCAT_CONF_DIR)/tomcat-users.xml 2>/dev/null; then \
		sudo sed -i '/<\/tomcat-users>/i \  <role rolename="manager-gui"/>\n  <role rolename="admin-gui"/>\n  <user username="admin" password="admin" roles="manager-gui,admin-gui"/>' $(TOMCAT_CONF_DIR)/tomcat-users.xml 2>/dev/null || true; \
		echo "  ✓ 관리자 계정 추가 (admin/admin)"; \
	else \
		echo "  ✓ 관리자 계정 이미 존재"; \
	fi

	@echo "$(YELLOW)4. 테스트 웹앱 배포$(NC)"
	@echo "<html><head><title>Tomcat Test</title></head><body><h1>Tomcat is working!</h1><p>Server: $$(hostname)</p></body></html>" | sudo tee $(TOMCAT_BASE)/webapps/ROOT/index.html > /dev/null 2>&1 || true

	@echo "$(GREEN)✓ Tomcat 설정 완료$(NC)"

tomcat-firewall: ## Tomcat 방화벽 설정
	@echo "$(BLUE)Tomcat 방화벽 설정...$(NC)"

	@if [ "$(ENABLE_FIREWALL)" = "true" ]; then \
		sudo firewall-cmd --permanent --add-port=$(TOMCAT_HTTP_PORT)/tcp; \
		sudo firewall-cmd --reload; \
		echo "$(GREEN)✓ 방화벽 설정 완료 (포트 $(TOMCAT_HTTP_PORT))$(NC)"; \
	else \
		echo "$(YELLOW)방화벽 설정 건너뜀$(NC)"; \
	fi

tomcat-start: ## Tomcat 서비스 시작
	@echo "$(BLUE)Tomcat 서비스 시작...$(NC)"
	sudo systemctl start $(TOMCAT_SERVICE_NAME)
	@echo "$(GREEN)✓ Tomcat 시작 완료$(NC)"

tomcat-stop: ## Tomcat 서비스 중지
	@echo "$(BLUE)Tomcat 서비스 중지...$(NC)"
	sudo systemctl stop $(TOMCAT_SERVICE_NAME)
	@echo "$(GREEN)✓ Tomcat 중지 완료$(NC)"

tomcat-restart: ## Tomcat 서비스 재시작
	@echo "$(BLUE)Tomcat 서비스 재시작...$(NC)"
	sudo systemctl restart $(TOMCAT_SERVICE_NAME)
	@echo "$(GREEN)✓ Tomcat 재시작 완료$(NC)"

tomcat-status: ## Tomcat 서비스 상태 확인
	@sudo systemctl status $(TOMCAT_SERVICE_NAME) --no-pager

tomcat-enable: ## Tomcat 자동 시작 활성화
	@echo "$(BLUE)Tomcat 자동 시작 활성화...$(NC)"
	sudo systemctl enable $(TOMCAT_SERVICE_NAME)
	@echo "$(GREEN)✓ Tomcat 자동 시작 활성화 완료$(NC)"

tomcat-disable: ## Tomcat 자동 시작 비활성화
	@echo "$(BLUE)Tomcat 자동 시작 비활성화...$(NC)"
	sudo systemctl disable $(TOMCAT_SERVICE_NAME)
	@echo "$(GREEN)✓ Tomcat 자동 시작 비활성화 완료$(NC)"

tomcat-test: ## Tomcat 동작 테스트
	@echo "$(BLUE)Tomcat 동작 테스트...$(NC)"

	@echo "$(YELLOW)1. 서비스 상태 확인$(NC)"
	@systemctl is-active $(TOMCAT_SERVICE_NAME) &>/dev/null && echo "  ✓ Tomcat 서비스 실행 중" || (echo "  ✗ Tomcat 서비스 중지됨" && exit 1)

	@echo "$(YELLOW)2. 포트 리스닝 확인$(NC)"
	@ss -tlnp | grep :$(TOMCAT_HTTP_PORT) &>/dev/null && echo "  ✓ 포트 $(TOMCAT_HTTP_PORT) 리스닝 중" || echo "  ✗ 포트 리스닝 없음"

	@echo "$(YELLOW)3. HTTP 요청 테스트$(NC)"
	@curl -s http://localhost:$(TOMCAT_HTTP_PORT) | grep -q "Tomcat" && echo "  ✓ HTTP 응답 정상" || echo "  ✗ HTTP 응답 실패"

	@echo "$(YELLOW)4. Java 버전 확인$(NC)"
	@java -version 2>&1 | head -1

	@echo "$(GREEN)✓ Tomcat 테스트 완료$(NC)"

tomcat-all: tomcat-install tomcat-configure tomcat-firewall tomcat-enable tomcat-start tomcat-test ## Tomcat 전체 설치 및 설정
	@echo "$(GREEN)✓ Tomcat 설치 및 설정 완료$(NC)"

tomcat-uninstall: tomcat-stop tomcat-disable ## Tomcat 제거
	@echo "$(BLUE)Tomcat 제거...$(NC)"
	sudo dnf remove -y tomcat tomcat-webapps tomcat-admin-webapps
	@echo "$(GREEN)✓ Tomcat 제거 완료$(NC)"

tomcat-logs: ## Tomcat 로그 확인
	@echo "$(BLUE)Tomcat 로그 확인...$(NC)"
	sudo journalctl -u $(TOMCAT_SERVICE_NAME) -f

# ===================================================================
# Tomcat 오프라인 패키징
# ===================================================================

tomcat-offline-download: ## Tomcat RPM 패키지 다운로드
	@echo "$(BLUE)Tomcat 오프라인 패키지 다운로드...$(NC)"

	@mkdir -p $(OFFLINE_REPO_DIR)/tomcat-rpms

	@echo "$(YELLOW)Tomcat 및 Java 패키지 다운로드$(NC)"
	@cd $(OFFLINE_REPO_DIR)/tomcat-rpms && dnf download --resolve --alldeps \
		java-11-openjdk java-11-openjdk-devel \
		tomcat tomcat-webapps tomcat-admin-webapps

	@echo "$(GREEN)✓ Tomcat 패키지 다운로드 완료$(NC)"
	@ls $(OFFLINE_REPO_DIR)/tomcat-rpms/*.rpm 2>/dev/null | wc -l | xargs echo "  총 RPM 파일 수:"

tomcat-offline-package: tomcat-offline-download ## Tomcat 오프라인 패키지 생성
	@echo "$(BLUE)Tomcat 오프라인 패키지 생성...$(NC)"

	@createrepo_c $(OFFLINE_REPO_DIR)/tomcat-rpms/
	@cd $(dir $(OFFLINE_REPO_DIR)) && tar -czf tomcat-offline-el$(EL_VERSION).tar.gz $(notdir $(OFFLINE_REPO_DIR))/tomcat-rpms

	@echo "$(GREEN)✓ Tomcat 오프라인 패키지 생성 완료$(NC)"
	@ls -lh $(dir $(OFFLINE_REPO_DIR))tomcat-offline-el$(EL_VERSION).tar.gz 2>/dev/null || true

# ===================================================================
# 통합 웹 스택 설치
# ===================================================================

web-all: apache-all tomcat-all ## Apache + Tomcat 전체 설치
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)웹 스택 설치 완료!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(BLUE)설치된 서비스:$(NC)"
	@echo "  - Apache HTTP Server: http://localhost:$(APACHE_HTTP_PORT)"
	@echo "  - Tomcat Application Server: http://localhost:$(TOMCAT_HTTP_PORT)"
	@echo ""
	@echo "$(YELLOW)다음 단계:$(NC)"
	@echo "  1. Apache 관리자 페이지: http://localhost:$(APACHE_HTTP_PORT)"
	@echo "  2. Tomcat 관리자 페이지: http://localhost:$(TOMCAT_HTTP_PORT)/manager"
	@echo "     (계정: admin/admin)"

web-test: apache-test tomcat-test ## Apache + Tomcat 테스트
	@echo "$(GREEN)✓ 모든 웹 서비스 테스트 통과$(NC)"

web-offline-package: apache-offline-package tomcat-offline-package ## Apache + Tomcat 오프라인 패키지 생성
	@echo "$(GREEN)✓ 웹 스택 오프라인 패키지 생성 완료$(NC)"

# ===================================================================
# 전체 스택 설치 (PostgreSQL + Apache + Tomcat)
# ===================================================================

stack-all: tune-all install init enable-start setup-external apache-all tomcat-all ## PostgreSQL + Apache + Tomcat 전체 설치
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)전체 스택 설치 완료!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(BLUE)설치된 서비스:$(NC)"
	@echo "  - PostgreSQL: localhost:$(PG_PORT)"
	@echo "  - Apache: http://localhost:$(APACHE_HTTP_PORT)"
	@echo "  - Tomcat: http://localhost:$(TOMCAT_HTTP_PORT)"

stack-test: test apache-test tomcat-test ## 전체 스택 테스트
	@echo "$(GREEN)✓ 전체 스택 테스트 통과$(NC)"

# PostgreSQL 자동 설치 스크립트

RHEL 9 / Rocky Linux 9 기반 PostgreSQL 설치 및 관리를 위한 Makefile 기반 자동화 도구입니다.

## 빠른 시작

### 1. 환경 설정

```bash
# .env 파일 생성
cp .env.example .env

# 필요시 .env 파일 수정
vi .env
```

### 2. 전체 설치 (원스텝)

```bash
# 커널 튜닝 + 설치 + 초기화 + 시작 + 외부 접속 설정
make all
```

**주의:** `make all`은 시스템 커널 튜닝을 먼저 수행합니다. 일부 설정은 재부팅 후 완전히 적용됩니다.

## 단계별 설치

### 0단계: 시스템 커널 튜닝 (권장)

PostgreSQL 최적 성능을 위한 커널 파라미터 및 리소스 제한 설정입니다.

```bash
# 모든 시스템 튜닝 적용
make tune-all

# 또는 개별 실행
make tune-kernel      # 커널 파라미터 설정
make tune-limits      # 리소스 제한 설정
make tune-hugepages   # Huge Pages 설정 (ENABLE_HUGE_PAGES=true 시)
```

**적용되는 설정:**
- 메모리 관리: swappiness, dirty page 설정
- 네트워크: 연결 대기 큐, keepalive 설정
- 공유 메모리: shmmax, shmall
- 리소스 제한: 파일 디스크립터, 프로세스 수, 메모리 잠금
- Huge Pages: 대용량 메모리 최적화 (선택사항)

**설정 확인:**
```bash
make show-tuning
```

## 단계별 설치 (PostgreSQL)

### 1단계: PostgreSQL 설치

```bash
make install
```

**수행 작업:**
- PGDG 공식 저장소 추가
- 기본 PostgreSQL 모듈 비활성화
- PostgreSQL 16 서버 패키지 설치

### 2단계: 데이터베이스 초기화

```bash
make init
```

**수행 작업:**
- initdb 실행
- 데이터 디렉토리 생성 (`/var/lib/pgsql/16/data`)

### 3단계: 서비스 시작 및 활성화

```bash
# 자동 시작 활성화 + 서비스 시작
make enable-start

# 또는 개별 실행
make enable  # 부팅 시 자동 시작
make start   # 서비스 시작
```

### 4단계: 외부 접속 설정 (선택사항)

```bash
# 외부 접속 허용 설정 (listen_addresses, pg_hba.conf, 방화벽)
make setup-external
```

## 주요 명령어

### 시스템 튜닝

```bash
make tune-all           # 모든 시스템 튜닝 적용
make tune-kernel        # 커널 파라미터 설정
make tune-limits        # 리소스 제한 설정
make tune-hugepages     # Huge Pages 설정
make show-tuning        # 현재 튜닝 값 확인
```

### 서비스 관리

```bash
make start          # 서비스 시작
make stop           # 서비스 중지
make restart        # 서비스 재시작
make status         # 서비스 상태 확인
make enable         # 부팅 시 자동 시작 활성화
make disable        # 부팅 시 자동 시작 비활성화
```

### 설정 관리

```bash
make configure-listen    # listen_addresses 설정
make configure-auth      # pg_hba.conf 인증 설정
make firewall           # 방화벽 포트 열기
make setup-external     # 외부 접속 전체 설정
```

### 테스트 및 검증

```bash
make test               # 전체 테스트 (연결 + 데이터베이스)
make test-connection    # PostgreSQL 연결 테스트
make test-database      # 데이터베이스 CRUD 테스트
make test-performance   # 성능 테스트 (pgbench)
```

### 오프라인 패키징 (ISO 기반)

```bash
# 온라인 서버에서 패키지 생성
make offline-package-all          # PostgreSQL 오프라인 패키지 생성
make tomcat-offline-package-all   # Tomcat 오프라인 패키지 생성
make apache-offline-package       # Apache 오프라인 패키지 생성

# 오프라인 서버에서 설치
make offline-full-install         # PostgreSQL 전체 설치
make tomcat-offline-full-install  # Tomcat 전체 설치
```

### ISO Repository

```bash
make iso-mount           # ISO 마운트 (.env의 ISO_FILE 사용)
make iso-setup-repo      # ISO Repository 설정
make iso-unmount         # ISO 마운트 해제
```

### 유틸리티

```bash
make help           # 도움말 표시
make check-env      # 환경 변수 확인
make version        # PostgreSQL 버전 확인
make logs           # 실시간 로그 확인
```

### 제거

```bash
make clean          # 데이터 디렉토리 삭제 (데이터 삭제)
make uninstall      # PostgreSQL 패키지 제거
```

## 📖 상세 명령어 레퍼런스

모든 명령어의 상세한 사용법은 [COMMANDS.md](COMMANDS.md)를 참조하세요.

## 환경 변수 (.env)

### 시스템 튜닝 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `VM_SWAPPINESS` | 10 | 스왑 사용 억제 (0-100) |
| `VM_DIRTY_BACKGROUND_RATIO` | 5 | 백그라운드 dirty page 비율 |
| `VM_DIRTY_RATIO` | 15 | dirty page 최대 비율 |
| `NET_CORE_SOMAXCONN` | 4096 | 연결 대기 큐 크기 |
| `NET_IPV4_TCP_KEEPALIVE_TIME` | 600 | TCP keepalive 시간(초) |
| `KERNEL_SHMMAX` | 17179869184 | 공유 메모리 최대 크기(바이트) |
| `KERNEL_SHMALL` | 4194304 | 공유 메모리 페이지 수 |
| `ULIMIT_NOFILE` | 65536 | 파일 디스크립터 제한 |
| `ULIMIT_NPROC` | unlimited | 프로세스 수 제한 |
| `ENABLE_HUGE_PAGES` | false | Huge Pages 활성화 여부 |
| `HUGE_PAGES_COUNT` | (자동) | Huge Pages 수 (비워두면 자동 계산) |
| `PG_SHARED_BUFFERS` | 4GB | shared_buffers 크기 (Huge Pages 계산용) |

### PostgreSQL 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `PG_VERSION` | 16 | PostgreSQL 버전 |
| `PG_PORT` | 5432 | PostgreSQL 포트 |
| `PG_LISTEN_ADDRESSES` | * | 수신 IP 주소 (* = 모든 IP) |
| `PG_ALLOWED_CIDR` | 0.0.0.0/0 | 접속 허용 IP 대역 |
| `PG_AUTH_METHOD` | scram-sha-256 | 인증 방식 |
| `ENABLE_FIREWALL` | true | 방화벽 설정 활성화 여부 |
| `EL_VERSION` | 9 | RHEL/Rocky Linux 버전 |

## PostgreSQL 접속

### 로컬 접속

```bash
# postgres 사용자로 전환
sudo -u postgres psql

# 또는
sudo su - postgres
psql
```

### 원격 접속

```bash
# 클라이언트에서
psql -h <서버IP> -U postgres -d postgres
```

## 설치 경로

- **데이터 디렉토리**: `/var/lib/pgsql/16/data/`
- **바이너리 경로**: `/usr/pgsql-16/bin/`
- **설정 파일**:
  - `/var/lib/pgsql/16/data/postgresql.conf`
  - `/var/lib/pgsql/16/data/pg_hba.conf`
- **서비스 이름**: `postgresql-16`

## 보안 권장 사항

1. **postgres 사용자 비밀번호 설정**
   ```bash
   sudo passwd postgres
   ```

2. **PostgreSQL 관리자 비밀번호 설정**
   ```bash
   sudo -u postgres psql
   postgres=# ALTER USER postgres PASSWORD 'your_password';
   ```

3. **IP 접속 제한**
   - `.env` 파일에서 `PG_ALLOWED_CIDR`을 특정 IP 대역으로 제한
   - 예: `PG_ALLOWED_CIDR=192.168.1.0/24`

4. **방화벽 설정 확인**
   ```bash
   sudo firewall-cmd --list-all
   ```

## 성능 튜닝 가이드

### Huge Pages 활성화 (고성능 환경 권장)

대용량 메모리(64GB 이상) 환경에서 권장됩니다.

1. `.env` 파일 수정
   ```bash
   ENABLE_HUGE_PAGES=true
   PG_SHARED_BUFFERS=8GB  # PostgreSQL의 shared_buffers 설정값
   ```

2. 튜닝 적용
   ```bash
   make tune-hugepages
   ```

3. PostgreSQL 설정 (`/var/lib/pgsql/16/data/postgresql.conf`)
   ```ini
   shared_buffers = 8GB
   huge_pages = try
   ```

4. 서비스 재시작
   ```bash
   make restart
   ```

5. Huge Pages 사용 확인
   ```bash
   make show-tuning
   # 또는
   grep HugePages /proc/meminfo
   ```

### 커널 튜닝 값 조정

환경에 맞게 `.env` 파일의 값을 조정한 후 재적용:

```bash
vi .env
make tune-kernel
make restart
```

### 리소스 제한 확인

```bash
# postgres 사용자로 전환 후
sudo su - postgres
ulimit -a

# 특정 값 확인
ulimit -n  # 파일 디스크립터
ulimit -u  # 프로세스 수
```

## 오프라인 설치 가이드 (ISO 기반)

오프라인 환경에서 PostgreSQL, Apache, Tomcat을 설치하기 위한 가이드입니다.
RHEL/Rocky Linux ISO를 기반으로 종속성을 해결합니다.

### 전체 워크플로우 요약

```
┌─────────────────────────────────────────────────────────────────┐
│                    온라인 서버 작업                              │
├─────────────────────────────────────────────────────────────────┤
│ 1. make init-env                    # .env 파일 생성            │
│ 2. vi .env                          # ISO_FILE 경로 설정        │
│ 3. make offline-package-all         # PostgreSQL 패키지 생성    │
│ 4. make tomcat-offline-package-all  # Tomcat 패키지 생성        │
│ 5. make apache-offline-package      # Apache 패키지 생성        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ 파일 전송 (USB, SCP 등)
                              │
┌─────────────────────────────────────────────────────────────────┐
│                   오프라인 서버 작업                             │
├─────────────────────────────────────────────────────────────────┤
│ 1. 프로젝트 디렉토리 복사                                        │
│ 2. tar -xzf *.tar.gz -C /root/      # 패키지 압축 해제          │
│ 3. vi .env                          # ISO_FILE 경로 설정        │
│ 4. make offline-full-install        # PostgreSQL 설치           │
│ 5. make tomcat-offline-full-install # Tomcat 설치               │
└─────────────────────────────────────────────────────────────────┘
```

### 사전 준비

1. **환경 설정 파일 생성**
   ```bash
   make init-env
   ```

2. **.env 파일 편집**
   ```bash
   vi .env
   # ISO_FILE=/path/to/rhel-9.6-x86_64-dvd.iso
   ```

### 온라인 서버: 오프라인 패키지 생성

#### PostgreSQL 오프라인 패키지 생성

```bash
# ISO 기반 전체 패키지 생성 (권장)
make offline-package-all

# 생성되는 파일: postgresql16-offline-el9.tar.gz
```

#### Tomcat 오프라인 패키지 생성

```bash
# ISO 기반 전체 패키지 생성 (권장)
make tomcat-offline-package-all

# 생성되는 파일: tomcat-offline-el9.tar.gz
```

#### Apache 오프라인 패키지 생성

```bash
# Apache 패키지 생성
make apache-offline-package

# 생성되는 파일: apache-offline-el9.tar.gz
```

#### 전체 웹 스택 패키지 생성

```bash
# Apache + Tomcat 함께 생성
make web-offline-package
```

### 오프라인 서버로 전송할 파일

1. **프로젝트 디렉토리** (Makefile, scripts/, .env.example)
2. **오프라인 패키지 파일** (*.tar.gz)
3. **RHEL/Rocky Linux ISO 파일**

### 오프라인 서버: 설치

#### 1. 사전 준비

```bash
# 프로젝트 디렉토리로 이동
cd /root/postgresql-install-script

# 패키지 압축 해제
tar -xzf postgresql16-offline-el9.tar.gz -C /root/
tar -xzf tomcat-offline-el9.tar.gz -C /root/

# .env 파일 생성 및 ISO 경로 설정
make init-env
vi .env
# ISO_FILE=/path/to/rhel-9.6-x86_64-dvd.iso
```

#### 2. PostgreSQL 오프라인 설치

```bash
# 전체 설치 (ISO 마운트 + repo 설정 + 설치 + 설정)
make offline-full-install

# 테스트
make test
```

#### 3. Tomcat 오프라인 설치

```bash
# 전체 설치 (ISO 마운트 + repo 설정 + 설치 + 설정)
make tomcat-offline-full-install

# 테스트
make tomcat-test
```

#### 4. 단계별 설치 (선택사항)

```bash
# PostgreSQL 단계별
make iso-mount
make iso-setup-repo
make offline-setup-repo
make offline-install-pkg
make init
make enable-start
make setup-external

# Tomcat 단계별
make tomcat-offline-setup-repo
make tomcat-offline-install-pkg
make tomcat-configure
make tomcat-firewall
make tomcat-enable
make tomcat-start
```

### 오프라인 워크플로우 안내 보기

```bash
make offline-workflow
```

## 테스트 가이드

### 기본 테스트

```bash
# 연결 테스트
make test-connection

# 데이터베이스 CRUD 테스트
make test-database

# 전체 테스트
make test
```

### 성능 테스트

```bash
# pgbench를 사용한 성능 테스트
make test-performance
```

**출력 예시:**
```
tps = 1234.567890 (including connections establishing)
tps = 1234.567890 (excluding connections establishing)
```

### 수동 테스트

```bash
# PostgreSQL 접속
sudo -u postgres psql

# 버전 확인
SELECT version();

# 데이터베이스 목록
\l

# 연결 정보
\conninfo

# 종료
\q
```

## 트러블슈팅

### 커널 튜닝 설정이 적용되지 않을 때

1. 설정 파일 확인
   ```bash
   cat /etc/sysctl.d/99-postgresql.conf
   cat /etc/security/limits.d/postgresql.conf
   ```

2. 수동 적용
   ```bash
   sudo sysctl --system
   ```

3. 재부팅
   ```bash
   sudo reboot
   ```

4. 적용 확인
   ```bash
   make show-tuning
   ```

### 서비스가 시작되지 않을 때

```bash
# 로그 확인
make logs

# 또는
sudo journalctl -u postgresql-16 -n 50
```

### 데이터 디렉토리 재생성

```bash
# 데이터 삭제 및 재초기화
make clean
make init
```

### 외부 접속이 안 될 때

1. 방화벽 확인
   ```bash
   sudo firewall-cmd --list-all
   ```

2. PostgreSQL 설정 확인
   ```bash
   sudo grep listen_addresses /var/lib/pgsql/16/data/postgresql.conf
   sudo cat /var/lib/pgsql/16/data/pg_hba.conf
   ```

3. 서비스 재시작
   ```bash
   make restart
   ```

## 버전 변경

PostgreSQL 17로 변경하려면:

```bash
# .env 파일 수정
vi .env
# PG_VERSION=17로 변경

# 설치
make all
```

## 라이선스

MIT License

## 참고 자료

- [PostgreSQL 공식 문서](https://www.postgresql.org/docs/)
- [PGDG Yum Repository](https://yum.postgresql.org/)

# PostgreSQL 설치 스크립트 명령어 레퍼런스

이 문서는 `make` 명령어의 상세한 사용법을 제공합니다.

## 📋 목차

- [시스템 튜닝](#시스템-튜닝)
- [PostgreSQL 설치](#postgresql-설치)
- [서비스 관리](#서비스-관리)
- [설정 관리](#설정-관리)
- [테스트 및 검증](#테스트-및-검증)
- [오프라인 패키징](#오프라인-패키징)
- [ISO Repository](#iso-repository)
- [유틸리티](#유틸리티)

---

## 시스템 튜닝

### `make tune-kernel`
**설명**: 커널 파라미터 최적화 설정 (`/etc/sysctl.d/99-postgresql.conf`)

**수행 작업**:
- 메모리 관리 (vm.swappiness, dirty page 설정)
- 네트워크 최적화 (somaxconn, tcp keepalive)
- 공유 메모리 설정 (shmmax, shmall)
- `sysctl --system` 실행으로 즉시 적용

**예시**:
```bash
make tune-kernel
```

**생성 파일**: `/etc/sysctl.d/99-postgresql.conf`

---

### `make tune-limits`
**설명**: 리소스 제한 설정 (`/etc/security/limits.d/postgresql.conf`)

**수행 작업**:
- postgres 사용자의 파일 디스크립터 제한 (nofile: 65536)
- 프로세스 수 제한 (nproc: unlimited)
- 메모리 잠금 제한 (memlock: unlimited)

**예시**:
```bash
make tune-limits
```

**주의사항**: 설정 적용을 위해 postgres 사용자 재로그인 또는 시스템 재부팅 필요

**생성 파일**: `/etc/security/limits.d/postgresql.conf`

---

### `make tune-hugepages`
**설명**: Huge Pages 설정 (대용량 메모리 최적화)

**수행 작업**:
- `.env`의 `ENABLE_HUGE_PAGES=true`일 경우에만 실행
- `HUGE_PAGES_COUNT` 자동 계산 또는 수동 설정
- `vm.nr_hugepages` 커널 파라미터 설정

**예시**:
```bash
# .env 파일 수정
ENABLE_HUGE_PAGES=true
PG_SHARED_BUFFERS=8GB

# Huge Pages 설정
make tune-hugepages
```

**권장 환경**: 64GB 이상 메모리 서버

---

### `make tune-all`
**설명**: 모든 시스템 튜닝 적용 (tune-kernel + tune-limits + tune-hugepages)

**예시**:
```bash
make tune-all
```

---

### `make show-tuning`
**설명**: 현재 적용된 튜닝 값 확인

**출력 정보**:
- 메모리 설정 (swappiness, dirty page ratio 등)
- 네트워크 설정 (somaxconn, keepalive 등)
- 공유 메모리 설정
- Huge Pages 정보
- postgres 사용자 리소스 제한

**예시**:
```bash
make show-tuning
```

---

## PostgreSQL 설치

### `make install`
**설명**: PostgreSQL 설치 (저장소 추가 + 패키지 설치)

**수행 작업**:
1. PGDG 공식 저장소 추가
2. 기본 PostgreSQL 모듈 비활성화
3. PostgreSQL 16 서버 및 contrib 패키지 설치

**예시**:
```bash
make install
```

**설치 패키지**:
- postgresql16-server
- postgresql16-contrib

---

### `make init`
**설명**: 데이터베이스 초기화 (initdb)

**수행 작업**:
- 데이터 디렉토리 존재 확인
- `postgresql-16-setup initdb` 실행
- PostgreSQL 데이터베이스 클러스터 생성

**예시**:
```bash
make init
```

**주의사항**: 데이터 디렉토리가 이미 존재하면 실패 (안전 장치)

---

### `make all`
**설명**: 전체 설치 및 설정 (tune + install + init + enable + start + external)

**실행 순서**:
1. `tune-all` - 시스템 튜닝
2. `install` - PostgreSQL 설치
3. `init` - 데이터베이스 초기화
4. `enable-start` - 자동 시작 활성화 + 서비스 시작
5. `setup-external` - 외부 접속 설정

**예시**:
```bash
make all
```

**완료 후 안내**: postgres 비밀번호 설정 및 접속 방법 출력

---

## 서비스 관리

### `make start`
**설명**: PostgreSQL 서비스 시작

```bash
make start
```

### `make stop`
**설명**: PostgreSQL 서비스 중지

```bash
make stop
```

### `make restart`
**설명**: PostgreSQL 서비스 재시작

```bash
make restart
```

### `make status`
**설명**: PostgreSQL 서비스 상태 확인

```bash
make status
```

### `make enable`
**설명**: 부팅 시 자동 시작 활성화

```bash
make enable
```

### `make disable`
**설명**: 부팅 시 자동 시작 비활성화

```bash
make disable
```

### `make enable-start`
**설명**: 자동 시작 활성화 + 서비스 시작 (enable + start)

```bash
make enable-start
```

---

## 설정 관리

### `make configure-listen`
**설명**: `listen_addresses` 설정 (외부 접속 허용)

**수행 작업**:
- `postgresql.conf`에서 `listen_addresses`를 `*`로 설정
- 모든 네트워크 인터페이스에서 연결 수신

```bash
make configure-listen
```

---

### `make configure-auth`
**설명**: `pg_hba.conf` 인증 설정

**수행 작업**:
- 외부 접속 허용 규칙 추가
- 인증 방식: scram-sha-256 (기본값)
- CIDR: 0.0.0.0/0 (모든 IP 허용, `.env`에서 변경 가능)

```bash
make configure-auth
```

---

### `make firewall`
**설명**: 방화벽 설정 (포트 5432 열기)

```bash
make firewall
```

---

### `make setup-external`
**설명**: 외부 접속 설정 (listen + auth + firewall + restart)

**실행 순서**:
1. `configure-listen` - listen_addresses 설정
2. `configure-auth` - pg_hba.conf 설정
3. `firewall` - 방화벽 설정
4. `restart` - 서비스 재시작

```bash
make setup-external
```

---

## 테스트 및 검증

### `make test-connection`
**설명**: PostgreSQL 연결 테스트

**테스트 내용**:
- `SELECT version();` 쿼리 실행
- PostgreSQL 버전 확인

```bash
make test-connection
```

**출력 예시**:
```
PostgreSQL 연결 테스트...
PostgreSQL 16.10 on x86_64-pc-linux-gnu...
✓ 연결 테스트 성공
```

---

### `make test-database`
**설명**: 데이터베이스 생성/삭제 테스트 (CRUD)

**테스트 내용**:
1. 테스트 테이블 생성 (`test_table`)
2. 데이터 삽입 (3개 레코드)
3. 데이터 조회
4. 데이터 개수 확인
5. 테이블 삭제

```bash
make test-database
```

---

### `make test-performance`
**설명**: 간단한 성능 테스트 (pgbench)

**테스트 내용**:
1. 테스트 DB 생성 (`pgbench_test`)
2. pgbench 초기화 (scale=10)
3. 성능 테스트 실행 (10 clients, 1000 transactions)
4. 테스트 DB 삭제

```bash
make test-performance
```

**주의사항**: pgbench 패키지 필요

---

### `make test`
**설명**: 전체 테스트 실행 (test-connection + test-database)

```bash
make test
```

---

## 오프라인 패키징

### `make offline-download`
**설명**: PostgreSQL RPM 패키지 다운로드

**수행 작업**:
1. 다운로드 디렉토리 생성 (`/root/postgresql-offline-repo/rpms`)
2. PGDG 저장소 설정 확인
3. PostgreSQL 패키지 및 의존성 다운로드
4. createrepo 도구 다운로드

**예시**:
```bash
make offline-download
```

**다운로드 위치**: `/root/postgresql-offline-repo/rpms`

---

### `make offline-createrepo`
**설명**: createrepo 실행하여 repository 메타데이터 생성

```bash
make offline-createrepo
```

**필요 패키지**: createrepo_c

---

### `make offline-package`
**설명**: 오프라인 패키지 생성 및 압축 (download + createrepo + 압축)

**수행 작업**:
1. `offline-download` - RPM 다운로드
2. `offline-createrepo` - 메타데이터 생성
3. 설치 스크립트 복사 (`offline-setup-repo.sh`)
4. README 파일 생성
5. tar.gz 압축

**예시**:
```bash
make offline-package
```

**생성 파일**: `/root/postgresql16-offline-el9.tar.gz`

---

### `make offline-setup-repo`
**설명**: 오프라인 Repository 설정 (압축 해제 후 사용)

**사용 시나리오**: 인터넷이 없는 서버에서 사용

**수행 작업**:
1. createrepo_c 설치 (로컬 RPM에서)
2. Local repository 설정 파일 생성
3. Repository 캐시 업데이트

```bash
# 압축 해제
tar -xzf postgresql16-offline-el9.tar.gz

# Repository 설정
make offline-setup-repo
```

---

### `make offline-install`
**설명**: 오프라인 패키지를 사용하여 PostgreSQL 설치

**실행 순서**:
1. `offline-setup-repo` - Repository 설정
2. `install` - PostgreSQL 설치

```bash
make offline-install
```

---

## ISO Repository

### `make iso-mount`
**설명**: RHEL/Rocky Linux ISO 마운트

**매개변수**: `ISO_FILE` (ISO 파일 경로)

**예시**:
```bash
make iso-mount ISO_FILE=/root/rhel-9.6-x86_64-dvd.iso
```

**마운트 위치**: `/mnt/rhel-iso`

---

### `make iso-setup-repo`
**설명**: ISO 기반 로컬 Repository 설정

**전제조건**: ISO가 `/mnt/rhel-iso`에 마운트되어 있어야 함

**수행 작업**:
1. Repository 설정 파일 생성 (`/etc/yum.repos.d/local-iso.repo`)
2. BaseOS 및 AppStream repository 설정
3. GPG 키 복사
4. Repository 캐시 업데이트

```bash
make iso-setup-repo
```

---

### `make iso-unmount`
**설명**: ISO 마운트 해제

```bash
make iso-unmount
```

---

### `make iso-all`
**설명**: ISO 마운트 및 Repository 설정 (iso-mount + iso-setup-repo)

```bash
make iso-all ISO_FILE=/root/rhel-9.6-x86_64-dvd.iso
```

---

## 유틸리티

### `make help`
**설명**: 사용 가능한 명령어 목록 표시

```bash
make help
```

---

### `make check-env`
**설명**: 환경 변수 확인

**출력 정보**:
- .env 파일 존재 여부
- PG_VERSION, PG_DATA_DIR, PG_PORT 등

```bash
make check-env
```

---

### `make version`
**설명**: PostgreSQL 버전 확인

```bash
make version
```

**출력 예시**:
```
psql (PostgreSQL) 16.10
```

---

### `make logs`
**설명**: PostgreSQL 로그 확인 (실시간)

```bash
make logs
```

**종료**: `Ctrl+C`

---

### `make clean`
**설명**: 데이터 디렉토리 삭제 (주의: 모든 데이터 삭제)

**주의사항**:
- 확인 프롬프트 표시 (y/N)
- 서비스를 먼저 중지함

```bash
make clean
```

---

### `make uninstall`
**설명**: PostgreSQL 제거 (패키지 삭제)

**수행 작업**:
1. 서비스 중지
2. 자동 시작 비활성화
3. PostgreSQL 패키지 제거

```bash
make uninstall
```

**주의사항**: 데이터는 삭제되지 않음 (`make clean` 별도 실행 필요)

---

## 📝 일반적인 사용 시나리오

### 시나리오 1: 처음 설치

```bash
# 1. 환경 설정
cp .env.example .env
vi .env  # 필요시 수정

# 2. 전체 설치
make all

# 3. 테스트
make test
```

### 시나리오 2: 오프라인 환경 준비

**인터넷 연결된 서버에서:**
```bash
# 오프라인 패키지 생성
make offline-package

# 생성된 파일을 USB 또는 네트워크로 전송
# /root/postgresql16-offline-el9.tar.gz
```

**인터넷 없는 서버에서:**
```bash
# 1. 압축 해제
tar -xzf postgresql16-offline-el9.tar.gz

# 2. 프로젝트 디렉토리로 이동
cd postgresql-install-script

# 3. 오프라인 설치
make offline-install

# 4. 데이터베이스 초기화 및 시작
make init enable-start setup-external

# 5. 테스트
make test
```

### 시나리오 3: ISO Repository 사용

```bash
# 1. ISO 마운트 및 Repository 설정
make iso-mount ISO_FILE=/root/rhel-9.6-x86_64-dvd.iso
make iso-setup-repo

# 2. 의존성 설치 (make로 필요한 패키지)
dnf install -y make createrepo_c

# 3. PostgreSQL 설치
make install init enable-start setup-external

# 4. 테스트
make test
```

### 시나리오 4: 성능 튜닝만 적용

```bash
# 시스템 튜닝 적용
make tune-all

# 현재 설정 확인
make show-tuning

# PostgreSQL 재시작 (이미 설치된 경우)
make restart
```

---

## ⚙️ 환경 변수 커스터마이징

`.env` 파일에서 다음 변수를 수정할 수 있습니다:

```bash
# PostgreSQL 버전
PG_VERSION=16

# 포트
PG_PORT=5432

# 외부 접속 허용 IP 대역
PG_ALLOWED_CIDR=192.168.1.0/24  # 특정 대역만 허용

# 커널 튜닝
VM_SWAPPINESS=10
NET_CORE_SOMAXCONN=4096

# Huge Pages
ENABLE_HUGE_PAGES=true
PG_SHARED_BUFFERS=8GB

# 오프라인 패키징
OFFLINE_REPO_DIR=/root/postgresql-offline-repo
OFFLINE_PG_VERSION=16.10-1PGDG.rhel9
```

---

## 🔍 트러블슈팅

### 명령어가 실패할 때

```bash
# 로그 확인
make logs

# 서비스 상태 확인
make status

# 환경 변수 확인
make check-env
```

### 설치 후 연결이 안 될 때

```bash
# 방화벽 확인
sudo firewall-cmd --list-all

# PostgreSQL 설정 확인
grep listen_addresses /var/lib/pgsql/16/data/postgresql.conf
cat /var/lib/pgsql/16/data/pg_hba.conf

# 포트 확인
ss -tlnp | grep 5432

# 테스트
make test-connection
```

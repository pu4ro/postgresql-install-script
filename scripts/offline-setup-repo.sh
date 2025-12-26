#!/bin/bash
# PostgreSQL 오프라인 Repository 설정 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 스크립트가 복사된 위치에 따라 rpms 경로 결정
if [ -d "${SCRIPT_DIR}/rpms" ]; then
    REPO_DIR="${SCRIPT_DIR}/rpms"
elif [ -d "${SCRIPT_DIR}/../rpms" ]; then
    REPO_DIR="${SCRIPT_DIR}/../rpms"
else
    echo "오류: rpms 디렉토리를 찾을 수 없습니다."
    exit 1
fi
PG_VERSION="${1:-16}"

echo "====================================="
echo "PostgreSQL 오프라인 Repository 설정"
echo "====================================="

# createrepo_c 설치 (로컬 RPM에서)
echo "1. createrepo_c 설치 중..."
if ! command -v createrepo_c &> /dev/null; then
    cd "${REPO_DIR}"
    rpm -ivh createrepo_c-*.rpm --force --nodeps 2>/dev/null || true
fi

# Local repository 설정
echo "2. Local repository 설정..."
cat > /etc/yum.repos.d/postgresql-local.repo << EOF
[postgresql-local]
name=PostgreSQL Local Repository
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
EOF

echo "3. Repository 캐시 업데이트..."
dnf clean all
dnf makecache

echo ""
echo "✓ 설정 완료!"
echo ""
echo "다음 명령어로 PostgreSQL을 설치할 수 있습니다:"
echo "  dnf install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib"

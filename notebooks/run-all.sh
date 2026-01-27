#!/bin/bash
#===============================================================================
# notebooks/run-all.sh - 모든 노트북 실행 및 검증
#===============================================================================
#
# 목적: 모든 Jupyter 노트북이 정상 실행되는지 자동 검증
#
# 사용법:
#   cd notebooks
#   ./run-all.sh
#
# 주의:
#   - 실행 전 Kind 클러스터가 실행 중이어야 합니다
#   - install.sh를 먼저 실행하여 환경을 구성해야 합니다
#
#===============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
OUTPUT_DIR="${SCRIPT_DIR}/output"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Jupyter 노트북 검증${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 사전 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[사전 확인] 환경 검증...${NC}"

# 가상환경 확인
if [ ! -d "${VENV_DIR}" ]; then
    echo -e "${RED}가상환경이 없습니다. 먼저 ./install.sh를 실행하세요.${NC}"
    exit 1
fi

# 클러스터 확인
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Kubernetes 클러스터에 연결할 수 없습니다.${NC}"
    echo "Kind 클러스터가 실행 중인지 확인하세요: kind get clusters"
    exit 1
fi

source "${VENV_DIR}/bin/activate"
echo -e "${GREEN}✓ 환경 확인 완료${NC}"
echo ""

# 출력 디렉토리 생성
mkdir -p "${OUTPUT_DIR}"

#-------------------------------------------------------------------------------
# 노트북 목록
#-------------------------------------------------------------------------------
NOTEBOOKS=(
    "00-환경검증.ipynb"
    "01-관측성.ipynb"
    "02-트래픽관리.ipynb"
    "03-복원력.ipynb"
    "04-보안.ipynb"
    "05-게이트웨이.ipynb"
)

TOTAL=${#NOTEBOOKS[@]}
PASSED=0
FAILED=0

#-------------------------------------------------------------------------------
# 노트북 실행
#-------------------------------------------------------------------------------
for i in "${!NOTEBOOKS[@]}"; do
    nb="${NOTEBOOKS[$i]}"
    num=$((i + 1))

    echo -e "${YELLOW}[${num}/${TOTAL}] ${nb} 실행 중...${NC}"

    if [ -f "${SCRIPT_DIR}/${nb}" ]; then
        # nbconvert로 노트북 실행 (출력은 HTML로 저장)
        if jupyter nbconvert --to html --execute \
            --ExecutePreprocessor.timeout=300 \
            --ExecutePreprocessor.kernel_name=python3 \
            --output-dir="${OUTPUT_DIR}" \
            "${SCRIPT_DIR}/${nb}" 2>&1; then
            echo -e "${GREEN}✓ ${nb} - 성공${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗ ${nb} - 실패${NC}"
            ((FAILED++))
        fi
    else
        echo -e "${RED}✗ ${nb} - 파일 없음${NC}"
        ((FAILED++))
    fi
    echo ""
done

#-------------------------------------------------------------------------------
# 결과 요약
#-------------------------------------------------------------------------------
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   검증 결과${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "총 노트북: ${TOTAL}개"
echo -e "${GREEN}성공: ${PASSED}개${NC}"
if [ ${FAILED} -gt 0 ]; then
    echo -e "${RED}실패: ${FAILED}개${NC}"
fi
echo ""
echo -e "실행 결과 HTML: ${OUTPUT_DIR}/"
echo ""

if [ ${FAILED} -gt 0 ]; then
    echo -e "${RED}일부 노트북 실행에 실패했습니다.${NC}"
    exit 1
else
    echo -e "${GREEN}모든 노트북이 정상 실행되었습니다!${NC}"
fi

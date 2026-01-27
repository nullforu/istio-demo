#!/bin/bash
#===============================================================================
# notebooks/install.sh - Jupyter 노트북 실행 환경 설정
#===============================================================================
#
# 목적: Istio Demo 노트북 실행을 위한 Python 환경 구성
#
# 사용법:
#   cd notebooks
#   ./install.sh
#
# 설치 항목:
#   - Python 가상환경 (uv 사용)
#   - Jupyter notebook
#   - nbconvert (노트북 실행/변환)
#   - ipykernel (Jupyter 커널)
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

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Jupyter 노트북 환경 설정${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 1. uv 설치 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] uv 설치 확인...${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${RED}uv가 설치되어 있지 않습니다.${NC}"
    echo "설치 방법: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi
echo -e "${GREEN}✓ uv $(uv --version)${NC}"
echo ""

#-------------------------------------------------------------------------------
# 2. 가상환경 생성
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/4] Python 가상환경 생성...${NC}"
if [ -d "${VENV_DIR}" ]; then
    echo "기존 가상환경 발견. 삭제 후 재생성..."
    rm -rf "${VENV_DIR}"
fi
uv venv "${VENV_DIR}"
echo -e "${GREEN}✓ 가상환경 생성 완료: ${VENV_DIR}${NC}"
echo ""

#-------------------------------------------------------------------------------
# 3. 패키지 설치
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/4] Jupyter 패키지 설치...${NC}"
source "${VENV_DIR}/bin/activate"
uv pip install jupyter nbconvert ipykernel
echo -e "${GREEN}✓ 패키지 설치 완료${NC}"
echo ""

#-------------------------------------------------------------------------------
# 4. Jupyter 커널 등록
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/4] Jupyter 커널 등록...${NC}"
python -m ipykernel install --user --name=istio-demo --display-name="Istio Demo (Python)"
echo -e "${GREEN}✓ 커널 등록 완료${NC}"
echo ""

#-------------------------------------------------------------------------------
# 완료
#-------------------------------------------------------------------------------
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   설치 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}노트북 실행 방법:${NC}"
echo ""
echo "  # 가상환경 활성화"
echo "  source ${VENV_DIR}/bin/activate"
echo ""
echo "  # Jupyter 노트북 실행"
echo "  jupyter notebook"
echo ""
echo "  # 또는 VS Code에서 열기"
echo "  code ."
echo ""
echo -e "${BLUE}노트북 검증 (CLI에서 실행):${NC}"
echo "  ./run-all.sh"
echo ""

#!/bin/bash
#===============================================================================
# 04-security-test.sh - 보안(Security) 테스트
#===============================================================================
#
# 목적: Istio의 접근 제어(Authorization Policy) 기능 테스트
#
# 테스트 시나리오:
#   1. 기본 상태 - 모든 트래픽 허용
#   2. DENY 정책 - 특정 서비스 차단
#   3. ALLOW 정책 - 특정 서비스만 허용
#   4. 경로/메서드별 세분화된 접근 제어
#
# 학습 포인트:
#   - Zero Trust 보안 모델
#   - 서비스 간 접근 제어를 코드 없이 구현
#   - 최소 권한 원칙 적용
#
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../03-security"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Module: Security (보안) 테스트${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 1: 기본 상태 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 1] 기본 상태 - 모든 트래픽 허용${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - Istio 기본 설정은 모든 서비스 간 통신 허용"
echo "  - sleep → httpbin 요청 가능"
echo ""

echo -e "${CYAN}테스트:${NC} sleep → httpbin 요청"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin:8000/get
echo ""

#-------------------------------------------------------------------------------
# 시나리오 2: DENY 정책 - 모든 트래픽 차단
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 2] DENY 정책 - 모든 트래픽 차단${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - httpbin에 대한 모든 요청 차단"
echo "  - RBAC: access denied 응답 (403)"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/authorization-policy-deny-all.yaml"

sleep 2
echo -e "${CYAN}테스트:${NC} sleep → httpbin 요청 (차단 예상)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code} (403 예상)\n" http://httpbin:8000/get
echo ""

kubectl delete -f "${MANIFESTS_DIR}/authorization-policy-deny-all.yaml" --ignore-not-found
sleep 1
echo ""

#-------------------------------------------------------------------------------
# 시나리오 3: ALLOW 정책 - 특정 서비스만 허용
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 3] ALLOW 정책 - sleep만 httpbin 접근 허용${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - httpbin은 sleep 서비스에서만 접근 가능"
echo "  - 다른 서비스의 요청은 차단"
echo "  - principals: service account 기반 식별"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/authorization-policy-allow-sleep.yaml"

sleep 2
echo -e "${CYAN}테스트:${NC} sleep → httpbin 요청 (허용)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code} (200 예상)\n" http://httpbin:8000/get
echo ""

kubectl delete -f "${MANIFESTS_DIR}/authorization-policy-allow-sleep.yaml" --ignore-not-found
sleep 1
echo ""

#-------------------------------------------------------------------------------
# 시나리오 4: 경로/메서드별 접근 제어
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 4] 경로/메서드별 세분화된 접근 제어${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - GET /get, /headers만 허용"
echo "  - POST /post는 차단"
echo "  - /status/* 경로는 차단"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/authorization-policy-path-based.yaml"

sleep 2
echo -e "${CYAN}테스트 1:${NC} GET /get (허용)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin:8000/get
echo ""

echo -e "${CYAN}테스트 2:${NC} GET /headers (허용)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin:8000/headers
echo ""

echo -e "${CYAN}테스트 3:${NC} POST /post (차단)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code} (403 예상)\n" -X POST http://httpbin:8000/post
echo ""

echo -e "${CYAN}테스트 4:${NC} GET /status/200 (차단)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code} (403 예상)\n" http://httpbin:8000/status/200
echo ""

kubectl delete -f "${MANIFESTS_DIR}/authorization-policy-path-based.yaml" --ignore-not-found
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   보안 테스트 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "다음 단계: ./05-gateway-test.sh 실행"

#!/bin/bash
#===============================================================================
# 02-traffic-test.sh - 트래픽 관리(Traffic Management) 테스트
#===============================================================================
#
# 목적: Istio의 트래픽 관리 기능 테스트
#
# 테스트 시나리오:
#   1. Canary 배포 (가중치 기반 라우팅)
#   2. 헤더 기반 라우팅
#   3. 트래픽 미러링
#
# 학습 포인트:
#   - VirtualService로 트래픽 분배 규칙 정의
#   - DestinationRule로 서비스 버전(subset) 정의
#   - 코드 수정 없이 배포 전략 구현
#
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../01-traffic-management"
DEMO_DIR="${SCRIPT_DIR}/.."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Module: Traffic Management 테스트${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 사전 준비: Backend v1, v2 배포
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[사전 준비] Backend v1, v2 배포${NC}"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/backend-v1.yaml"
kubectl apply -f "${MANIFESTS_DIR}/backend-v2.yaml"
kubectl apply -f "${MANIFESTS_DIR}/backend-service.yaml"

echo "Backend v1, v2 배포 완료. Pod 시작 대기..."
sleep 10
kubectl get pods -n istio-demo -l app=backend
echo ""

#-------------------------------------------------------------------------------
# DestinationRule 설정 (서비스 버전 정의)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[설정] DestinationRule - 서비스 버전(subset) 정의${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - DestinationRule은 서비스의 '버전'을 정의합니다."
echo "  - label selector로 v1, v2를 구분합니다."
echo ""

kubectl apply -f "${MANIFESTS_DIR}/destination-rule.yaml"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 1: Canary 배포 (90% v1, 10% v2)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 1] Canary 배포 - 90% v1, 10% v2${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - 새 버전(v2)을 10%의 트래픽으로만 테스트"
echo "  - 문제 없으면 점진적으로 비율 증가"
echo "  - 롤백이 필요하면 weight만 변경"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/virtual-service-canary.yaml"

echo -e "${CYAN}테스트:${NC} 20회 요청 중..."
V1_COUNT=0
V2_COUNT=0
for i in $(seq 1 20); do
    RESPONSE=$(kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://backend:8080 2>/dev/null)
    if echo "$RESPONSE" | grep -q "v1"; then
        ((V1_COUNT++))
    elif echo "$RESPONSE" | grep -q "v2"; then
        ((V2_COUNT++))
    fi
done
echo ""
echo -e "${GREEN}결과: v1=${V1_COUNT}회, v2=${V2_COUNT}회 (예상: v1≈18, v2≈2)${NC}"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 2: 헤더 기반 라우팅
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 2] 헤더 기반 라우팅${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - 특정 헤더가 있으면 v2로 라우팅"
echo "  - QA팀/Beta 테스터만 새 버전 접근 가능"
echo "  - A/B 테스트에 활용"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/virtual-service-header.yaml"

echo -e "${CYAN}테스트 1:${NC} 헤더 없이 요청 (→ v1)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://backend:8080
echo ""

echo -e "${CYAN}테스트 2:${NC} x-version: v2 헤더로 요청 (→ v2)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s -H "x-version: v2" http://backend:8080
echo ""

#-------------------------------------------------------------------------------
# 정리
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[정리] 리소스 삭제${NC}"
read -p "테스트 리소스를 삭제하시겠습니까? (y/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    kubectl delete -f "${MANIFESTS_DIR}/virtual-service-canary.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/virtual-service-header.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/destination-rule.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/backend-service.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/backend-v1.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/backend-v2.yaml" --ignore-not-found
    echo "정리 완료!"
else
    echo "리소스 유지. 수동 삭제: kubectl delete -f ${MANIFESTS_DIR}/"
fi
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   트래픽 관리 테스트 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "다음 단계: ./03-resiliency-test.sh 실행"

#!/bin/bash
#===============================================================================
# 00-setup-test.sh - 환경 설정 확인 스크립트
#===============================================================================
# 
# 목적: Istio Demo 환경이 정상적으로 설정되었는지 확인
# 
# 확인 항목:
#   1. Kind 클러스터 상태
#   2. Istio 컴포넌트 상태
#   3. Observability 스택 상태 (Jaeger, Prometheus, Grafana)
#   4. 샘플 애플리케이션 상태
#   5. Sidecar Injection 확인
#
#===============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Istio Demo 환경 설정 확인${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 1. 클러스터 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] 클러스터 상태 확인...${NC}"
echo "현재 context: $(kubectl config current-context)"
echo ""
kubectl get nodes
echo ""

#-------------------------------------------------------------------------------
# 2. Istio 컴포넌트 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/5] Istio 컴포넌트 확인...${NC}"
kubectl get pods -n istio-system
echo ""

# Istio 버전 확인
echo "Istio 버전:"
kubectl get deployment istiod -n istio-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "istiod not found"
echo ""

#-------------------------------------------------------------------------------
# 3. Observability 스택 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/5] Observability 스택 확인...${NC}"
echo "--- Jaeger ---"
kubectl get pods -n observability -l app.kubernetes.io/name=jaeger
echo ""
echo "--- Prometheus & Grafana ---"
kubectl get pods -n monitoring
echo ""

#-------------------------------------------------------------------------------
# 4. 샘플 애플리케이션 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/5] 샘플 애플리케이션 확인...${NC}"
kubectl get pods -n istio-demo
echo ""

# demo-app 백엔드 서비스 확인
echo "demo-app 백엔드 서비스 상태:"
echo -n "  - Redis: "
kubectl get pods -n istio-demo -l app=redis --no-headers 2>/dev/null | grep -q "Running" && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Not Running${NC}"
echo -n "  - MongoDB: "
kubectl get pods -n istio-demo -l app=mongodb --no-headers 2>/dev/null | grep -q "Running" && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Not Running${NC}"
echo ""

#-------------------------------------------------------------------------------
# 5. Sidecar Injection 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[5/5] Sidecar Injection 확인...${NC}"
echo "istio-demo 네임스페이스 레이블:"
kubectl get namespace istio-demo --show-labels | grep -o 'istio-injection=[^,]*' || echo "istio-injection label not found"
echo ""

# Pod 컨테이너 수 확인 (2/2 = sidecar 정상)
echo "Pod 컨테이너 수 (2/2 = sidecar 정상):"
kubectl get pods -n istio-demo -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name"
echo ""

#-------------------------------------------------------------------------------
# 요약
#-------------------------------------------------------------------------------
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   환경 설정 확인 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "다음 단계: ./01-observability-test.sh 실행"

#!/bin/bash
#===============================================================================
# 05-gateway-test.sh - Gateway API 테스트
#===============================================================================
#
# 목적: Kubernetes Gateway API를 활용한 외부 트래픽 관리 테스트
#
# 테스트 시나리오:
#   1. Gateway 리소스 생성
#   2. HTTPRoute로 기본 라우팅
#   3. HTTPRoute로 가중치 기반 라우팅 (Canary)
#   4. HTTPRoute로 헤더 기반 라우팅
#
# 학습 포인트:
#   - Gateway API는 Kubernetes 표준 API (Ingress 대체)
#   - Istio, Envoy Gateway, Kong 등 다양한 구현체 지원
#   - VirtualService와 유사하지만 더 표준화된 방식
#
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../05-gateway"
TRAFFIC_DIR="${SCRIPT_DIR}/../01-traffic-management"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Module: Gateway API 테스트${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# Gateway API CRD 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[사전 확인] Gateway API CRD 설치 여부${NC}"
echo ""

if kubectl get crd gateways.gateway.networking.k8s.io &>/dev/null; then
    echo -e "${GREEN}Gateway API CRD가 설치되어 있습니다.${NC}"
else
    echo -e "${YELLOW}Gateway API CRD 설치 중...${NC}"
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
    sleep 3
fi
echo ""

#-------------------------------------------------------------------------------
# Backend v1, v2 배포 (이전 테스트에서 삭제된 경우)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[사전 준비] Backend 서비스 확인${NC}"
if ! kubectl get deployment backend-v1 -n istio-demo &>/dev/null; then
    echo "Backend v1, v2 배포 중..."
    kubectl apply -f "${TRAFFIC_DIR}/backend-v1.yaml"
    kubectl apply -f "${TRAFFIC_DIR}/backend-v2.yaml"
    kubectl apply -f "${MANIFESTS_DIR}/backend-v1-service.yaml"
    kubectl apply -f "${MANIFESTS_DIR}/backend-v2-service.yaml"
    sleep 10
fi
echo ""

#-------------------------------------------------------------------------------
# 시나리오 1: Gateway 리소스 생성
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 1] Gateway 리소스 생성${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - Gateway는 외부 트래픽의 진입점"
echo "  - gatewayClassName: istio → Istio가 이 Gateway 관리"
echo "  - listeners: 수신할 포트와 프로토콜 정의"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/gateway.yaml"

echo "Gateway 생성 대기 중..."
sleep 5
kubectl get gateway demo-gateway -n istio-demo
echo ""

# Gateway 서비스 IP 확인
GATEWAY_IP=$(kubectl get gateway demo-gateway -n istio-demo -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "pending")
echo "Gateway IP: ${GATEWAY_IP}"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 2: HTTPRoute - 기본 라우팅
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 2] HTTPRoute - 기본 라우팅${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - HTTPRoute는 VirtualService와 유사한 역할"
echo "  - parentRefs: 어떤 Gateway에 연결할지 지정"
echo "  - backendRefs: 트래픽을 보낼 서비스 지정"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/httproute-basic.yaml"

echo -e "${CYAN}테스트:${NC} Gateway를 통한 httpbin 접근"
# Gateway Pod 찾기
GATEWAY_POD=$(kubectl get pods -n istio-demo -l istio.io/gateway-name=demo-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$GATEWAY_POD" ]]; then
    kubectl exec -n istio-demo "$GATEWAY_POD" -- curl -s -H "Host: httpbin.local" http://localhost/get | head -10
else
    echo "Gateway Pod 시작 대기 중... sleep에서 직접 테스트:"
    kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get | head -5
fi
echo ""

#-------------------------------------------------------------------------------
# 시나리오 3: HTTPRoute - 가중치 기반 라우팅
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 3] HTTPRoute - 가중치 기반 라우팅 (Canary)${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - weight를 사용하여 트래픽 분배"
echo "  - VirtualService의 weight와 동일한 기능"
echo "  - Kubernetes 표준 API로 Canary 배포 구현"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/httproute-canary.yaml"

echo -e "${CYAN}HTTPRoute YAML:${NC}"
echo "  backendRefs:"
echo "    - name: backend-v1, weight: 80"
echo "    - name: backend-v2, weight: 20"
echo ""
echo "→ 80%는 v1, 20%는 v2로 라우팅"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 4: HTTPRoute - 헤더 기반 라우팅
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 4] HTTPRoute - 헤더 기반 라우팅${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - matches.headers로 특정 헤더 매칭"
echo "  - x-version: v2 헤더가 있으면 v2로 라우팅"
echo "  - A/B 테스트, 특정 사용자 그룹 라우팅에 활용"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/httproute-header.yaml"

echo -e "${CYAN}HTTPRoute YAML:${NC}"
echo "  rules:"
echo "    - matches:"
echo "        - headers:"
echo "            - name: x-version"
echo "              value: v2"
echo "      backendRefs: [backend-v2]"
echo "    - backendRefs: [backend-v1]  # 기본값"
echo ""

#-------------------------------------------------------------------------------
# Gateway API vs Istio API 비교
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[비교] Gateway API vs Istio API${NC}"
echo ""
echo "┌─────────────────┬───────────────────────────┬───────────────────────────┐"
echo "│ 항목            │ Istio API                 │ Gateway API               │"
echo "├─────────────────┼───────────────────────────┼───────────────────────────┤"
echo "│ Gateway         │ networking.istio.io       │ gateway.networking.k8s.io │"
echo "│ 라우팅          │ VirtualService            │ HTTPRoute                 │"
echo "│ 표준화          │ Istio 전용                │ Kubernetes 표준           │"
echo "│ 호환성          │ Istio만                   │ 다양한 구현체 지원        │"
echo "│ 성숙도          │ 매우 안정적               │ GA (v1.0+)                │"
echo "└─────────────────┴───────────────────────────┴───────────────────────────┘"
echo ""

#-------------------------------------------------------------------------------
# 정리
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[정리] 리소스 삭제${NC}"
read -p "테스트 리소스를 삭제하시겠습니까? (y/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    kubectl delete -f "${MANIFESTS_DIR}/httproute-basic.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/httproute-canary.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/httproute-header.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/gateway.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/backend-v1-service.yaml" --ignore-not-found
    kubectl delete -f "${MANIFESTS_DIR}/backend-v2-service.yaml" --ignore-not-found
    kubectl delete -f "${TRAFFIC_DIR}/backend-v1.yaml" --ignore-not-found
    kubectl delete -f "${TRAFFIC_DIR}/backend-v2.yaml" --ignore-not-found
    echo "정리 완료!"
else
    echo "리소스 유지됨. 수동 삭제: kubectl delete -f ${MANIFESTS_DIR}/"
fi
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Gateway API 테스트 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${GREEN}모든 테스트가 완료되었습니다!${NC}"
echo ""
echo "추가 학습 자료:"
echo "  - Gateway API: https://gateway-api.sigs.k8s.io/"
echo "  - Istio + Gateway API: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/"

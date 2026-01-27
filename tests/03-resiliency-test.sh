#!/bin/bash
#===============================================================================
# 03-resiliency-test.sh - 복원력(Resiliency) 테스트
#===============================================================================
#
# 목적: Istio의 복원력 기능 테스트
#
# 테스트 시나리오:
#   1. Timeout - 응답 지연 시 자동 타임아웃
#   2. Retry - 실패 시 자동 재시도
#   3. Fault Injection - 장애 시뮬레이션
#   4. Circuit Breaker - 연쇄 장애 방지
#
# 학습 포인트:
#   - 코드 수정 없이 장애 대응 패턴 적용
#   - 마이크로서비스 장애 격리
#   - 카오스 엔지니어링 기초
#
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../02-resiliency"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Module: Resiliency (복원력) 테스트${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 1: Timeout 설정
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 1] Timeout - 응답 지연 대응${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - httpbin /delay/5 엔드포인트는 5초 지연 응답"
echo "  - VirtualService로 2초 timeout 설정"
echo "  - 2초 초과 시 504 Gateway Timeout 반환"
echo ""

# Timeout VirtualService 적용
kubectl apply -f "${MANIFESTS_DIR}/virtual-service-timeout.yaml"

echo -e "${CYAN}테스트 1:${NC} /get 요청 (빠른 응답 → 성공)"
time kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin:8000/get
echo ""

echo -e "${CYAN}테스트 2:${NC} /delay/5 요청 (5초 지연 → 2초에 timeout)"
time kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://httpbin:8000/delay/5 2>/dev/null || echo "Timeout 발생!"
echo ""

kubectl delete -f "${MANIFESTS_DIR}/virtual-service-timeout.yaml" --ignore-not-found
echo ""

#-------------------------------------------------------------------------------
# 시나리오 2: Retry 설정
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 2] Retry - 자동 재시도${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - httpbin /status/503은 항상 503 에러 반환"
echo "  - VirtualService로 3회 재시도 설정"
echo "  - 재시도 로그를 Envoy에서 확인"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/virtual-service-retry.yaml"

echo -e "${CYAN}테스트:${NC} /status/503 요청 (3회 재시도 후 최종 503)"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s -o /dev/null -w "HTTP %{http_code} (3회 재시도 후)\n" http://httpbin:8000/status/503
echo ""

echo -e "${CYAN}Envoy 로그에서 재시도 확인:${NC}"
kubectl logs -n istio-demo deploy/sleep -c istio-proxy --tail=5 | grep -E "status/503|upstream_reset" | head -3 || echo "(로그에서 재시도 흔적 확인)"
echo ""

kubectl delete -f "${MANIFESTS_DIR}/virtual-service-retry.yaml" --ignore-not-found
echo ""

#-------------------------------------------------------------------------------
# 시나리오 3: Fault Injection (장애 주입)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 3] Fault Injection - 장애 시뮬레이션${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - 50% 요청에 2초 지연 주입"
echo "  - 10% 요청에 500 에러 주입"
echo "  - 카오스 엔지니어링으로 시스템 복원력 테스트"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/virtual-service-fault-injection.yaml"

echo -e "${CYAN}테스트:${NC} 10회 요청 (일부 지연, 일부 500 에러 예상)"
SUCCESS=0
DELAY=0
ERROR=0
for i in $(seq 1 10); do
    START=$(date +%s.%N)
    CODE=$(kubectl exec -n istio-demo deploy/sleep -c sleep -- \
        curl -s -o /dev/null -w "%{http_code}" http://httpbin:8000/get 2>/dev/null || echo "000")
    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)
    
    if [[ "$CODE" == "500" ]]; then
        ((ERROR++))
        echo -n "❌"
    elif (( $(echo "$DURATION > 2" | bc -l) )); then
        ((DELAY++))
        echo -n "⏱️"
    else
        ((SUCCESS++))
        echo -n "✅"
    fi
done
echo ""
echo -e "${GREEN}결과: 성공=${SUCCESS}, 지연=${DELAY}, 에러=${ERROR}${NC}"
echo ""

kubectl delete -f "${MANIFESTS_DIR}/virtual-service-fault-injection.yaml" --ignore-not-found
echo ""

#-------------------------------------------------------------------------------
# 시나리오 4: Circuit Breaker
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 4] Circuit Breaker - 연쇄 장애 방지${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - 동시 연결 수 제한 (maxConnections: 1)"
echo "  - 대기 요청 수 제한 (http1MaxPendingRequests: 1)"
echo "  - 초과 요청은 503으로 즉시 거부 → 장애 격리"
echo ""

kubectl apply -f "${MANIFESTS_DIR}/destination-rule-circuit-breaker.yaml"

echo -e "${CYAN}테스트:${NC} 동시 5개 요청 (일부 503 예상)"
for i in $(seq 1 5); do
    kubectl exec -n istio-demo deploy/sleep -c sleep -- \
        curl -s -o /dev/null -w "요청 $i: HTTP %{http_code}\n" http://httpbin:8000/delay/1 &
done
wait
echo ""

kubectl delete -f "${MANIFESTS_DIR}/destination-rule-circuit-breaker.yaml" --ignore-not-found
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   복원력 테스트 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "다음 단계: ./04-security-test.sh 실행"

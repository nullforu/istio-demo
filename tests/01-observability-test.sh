#!/bin/bash
#===============================================================================
# 01-observability-test.sh - 관측성(Observability) 테스트
#===============================================================================
#
# 목적: Istio의 관측성 기능 테스트
#
# 테스트 시나리오:
#   1. 트래픽 생성 → Jaeger에서 분산 트레이싱 확인
#   2. Prometheus 메트릭 수집 확인
#   3. Grafana 대시보드 접근
#
# 학습 포인트:
#   - Envoy Sidecar가 자동으로 트레이스 헤더 전파
#   - 코드 수정 없이 분산 트레이싱 구현
#   - Service Mesh의 핵심 가치: 관측성 자동화
#
#===============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Module: Observability (관측성) 테스트${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 1: 트래픽 생성 및 트레이싱 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 1] 트래픽 생성 및 분산 트레이싱${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - sleep pod에서 httpbin 서비스로 요청을 보냅니다."
echo "  - Envoy sidecar가 자동으로 트레이스 헤더(X-B3-*)를 추가합니다."
echo "  - Jaeger에서 전체 요청 경로를 추적할 수 있습니다."
echo ""

echo -e "${CYAN}실행:${NC} 트래픽 10회 생성 중..."
for i in $(seq 1 10); do
    kubectl exec -n istio-demo deploy/sleep -c sleep -- \
        curl -s http://httpbin.istio-demo:8000/get > /dev/null
    echo -n "."
done
echo " 완료!"
echo ""

echo -e "${CYAN}트레이스 헤더 확인:${NC}"
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s http://httpbin.istio-demo:8000/headers | grep -E "X-B3|X-Request-Id" || true
echo ""

#-------------------------------------------------------------------------------
# 시나리오 2: Jaeger 서비스 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 2] Jaeger 트레이스 수집 확인${NC}"
echo ""

echo -e "${CYAN}등록된 서비스 목록:${NC}"
SERVICES=$(kubectl exec -n observability deploy/jaeger -- \
    wget -qO- "http://localhost:16686/api/services" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print('\n'.join(d.get('data',[])))" 2>/dev/null || echo "조회 실패")
echo "$SERVICES"
echo ""

echo -e "${CYAN}최근 트레이스:${NC}"
kubectl exec -n observability deploy/jaeger -- \
    wget -qO- "http://localhost:16686/api/traces?service=httpbin.istio-demo&limit=3" 2>/dev/null | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
traces = d.get('data',[])
print(f'총 {len(traces)}개 트레이스 조회')
for t in traces[:3]:
    spans = t.get('spans',[])
    print(f'  TraceID: {t[\"traceID\"][:16]}... | Spans: {len(spans)}개')
" 2>/dev/null || echo "트레이스 조회 실패"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 3: demo-app OpenTelemetry 트레이싱
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 3] demo-app OpenTelemetry 트레이싱${NC}"
echo ""
echo -e "${CYAN}설명:${NC}"
echo "  - demo-app은 Redis, MongoDB 자동 instrumentation 포함"
echo "  - 각 데이터베이스 작업이 별도의 span으로 기록됨"
echo ""

echo -e "${CYAN}실행:${NC} Redis 트레이싱 테스트..."
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s http://demo-app.istio-demo:8080/redis-demo 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Redis: {d.get(\"message\", \"error\")}')" 2>/dev/null || echo "  Redis demo 호출 실패"
echo ""

echo -e "${CYAN}실행:${NC} MongoDB 트레이싱 테스트..."
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s http://demo-app.istio-demo:8080/mongo-demo 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  MongoDB: {d.get(\"message\", \"error\")}')" 2>/dev/null || echo "  MongoDB demo 호출 실패"
echo ""

echo -e "${CYAN}실행:${NC} Full Demo (Redis + MongoDB + httpbin)..."
kubectl exec -n istio-demo deploy/sleep -c sleep -- \
    curl -s http://demo-app.istio-demo:8080/full-demo 2>/dev/null | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
results = d.get('results', {})
print(f'  Step 1: {results.get(\"step1\", \"?\")}'[:50])
print(f'  Step 2: {results.get(\"step2\", \"?\")}'[:50])
print(f'  Step 3: {results.get(\"step3\", \"?\")}'[:50])
print(f'  Step 4: {results.get(\"step4\", \"?\")}'[:50])
" 2>/dev/null || echo "  Full demo 호출 실패"
echo ""

#-------------------------------------------------------------------------------
# 시나리오 4: Prometheus 메트릭 확인
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[시나리오 4] Prometheus 메트릭 확인${NC}"
echo ""

echo -e "${CYAN}Istio 메트릭 예시 (istio_requests_total):${NC}"
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- \
    wget -qO- 'http://localhost:9090/api/v1/query?query=istio_requests_total' 2>/dev/null | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
results = d.get('data',{}).get('result',[])
print(f'총 {len(results)}개 메트릭 시리즈')
for r in results[:3]:
    labels = r.get('metric',{})
    src = labels.get('source_workload','unknown')
    dst = labels.get('destination_workload','unknown')
    code = labels.get('response_code','?')
    print(f'  {src} → {dst} (HTTP {code})')
" 2>/dev/null || echo "메트릭 조회 실패 (트래픽 생성 후 다시 시도)"
echo ""

#-------------------------------------------------------------------------------
# Port Forward 안내
#-------------------------------------------------------------------------------
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   UI 접속 방법${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}Jaeger UI (분산 트레이싱):${NC}"
echo "  kubectl port-forward -n observability svc/jaeger 16686:16686"
echo "  → http://localhost:16686"
echo "  → Service: demo-app 선택 시 Redis/MongoDB/httpbin 트레이스 확인"
echo ""
echo -e "${CYAN}Grafana (대시보드):${NC}"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  → http://localhost:3000 (admin/admin)"
echo ""
echo -e "${CYAN}Prometheus (메트릭):${NC}"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  → http://localhost:9090"
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   관측성 테스트 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "다음 단계: ./02-traffic-test.sh 실행"

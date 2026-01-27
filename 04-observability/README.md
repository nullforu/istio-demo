# Module 4: Observability (관측성)

## 목표
Istio의 관측성 도구(Kiali, Jaeger, Prometheus, Grafana)를 활용하여 서비스 메시를 모니터링합니다.

## 사전 준비

```bash
# 트래픽 생성 (관측 데이터 수집)
for i in $(seq 1 20); do
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://demo-app:8080/full-demo
done
```

## 도구별 접속

### Kiali (Service Graph)

```bash
kubectl port-forward -n observability svc/kiali 20001:20001
# http://localhost:20001
```

**확인 포인트**:
- 서비스 간 연결 시각화
- 트래픽 흐름 애니메이션
- 설정 검증

### Jaeger (Distributed Tracing)

```bash
kubectl port-forward -n observability svc/jaeger 16686:16686
# http://localhost:16686
```

**확인 포인트**:
- 요청의 전체 경로 추적
- 서비스별 지연시간
- 에러 발생 지점

### Grafana (Metrics Dashboard)

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# http://localhost:3000 (admin/admin)
```

**확인 포인트**:
- Istio Service Dashboard
- Istio Workload Dashboard
- Request Rate, Error Rate, Latency

### Prometheus (Raw Metrics)

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# http://localhost:9090
```

**확인 쿼리**:
```promql
# 요청 수
istio_requests_total

# 요청 지연시간
histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m]))

# 에러율
sum(rate(istio_requests_total{response_code=~"5.."}[5m])) / sum(rate(istio_requests_total[5m]))
```

## Gateway 리소스 (외부 접근용)

```bash
# 각 도구의 외부 접근 Gateway 적용
kubectl apply -f kiali-gateway.yaml
kubectl apply -f jaeger-gateway.yaml
kubectl apply -f grafana-gateway.yaml
```

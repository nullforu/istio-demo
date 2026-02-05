# Module 2: Resiliency (복원력)

## 목표

**Gateway API (HTTPRoute)**와 Istio를 사용하여 서비스의 복원력을 높이는 방법을 학습합니다.

## API 방식 비교

| 기능 | Gateway API | Istio API |
|------|-------------|-----------|
| Timeout | ✅ `HTTPRoute.timeouts` | `VirtualService` |
| Retry | ✅ `HTTPRoute` + Istio 확장 | `VirtualService` |
| Fault Injection | ❌ 미지원 | `VirtualService` (Istio 전용) |
| Circuit Breaker | ❌ 미지원 | `DestinationRule` (Istio 전용) |

## 실습 시나리오

### 시나리오 1: Timeout (타임아웃) - Gateway API

```bash
# Gateway API HTTPRoute 적용
kubectl apply -f httproute-timeout.yaml

# 빠른 요청 (성공)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get

# 5초 지연 요청 (2초에 타임아웃)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/delay/5
```

### 시나리오 2: Retry (재시도) - Gateway API

```bash
# Gateway API HTTPRoute 적용 (Istio 확장 annotation 사용)
kubectl apply -f httproute-retry.yaml

# 503 에러 (3회 재시도 후 실패)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/status/503
```

### 시나리오 3: Fault Injection (장애 주입) - Istio 전용

> ⚠️ **Gateway API 미지원**: Fault Injection은 Istio VirtualService에서만 지원됩니다.

```bash
# Istio VirtualService 적용 (Gateway API 대안 없음)
kubectl apply -f virtual-service-fault-injection.yaml

# 일부 요청에 지연/에러 발생
for i in $(seq 1 10); do
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s -o /dev/null -w "%{http_code}\n" http://httpbin:8000/get
done
```

### 시나리오 4: Circuit Breaker (서킷 브레이커) - Istio 전용

> ⚠️ **Gateway API 미지원**: Circuit Breaker는 Istio DestinationRule에서만 지원됩니다.

```bash
# Istio DestinationRule 적용 (Gateway API 대안 없음)
kubectl apply -f destination-rule-circuit-breaker.yaml

# 동시 요청으로 서킷 브레이커 트리거
for i in $(seq 1 5); do
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/delay/1 &
done
wait
```

## 파일 구조

```text
02-resiliency/
├── httproute-timeout.yaml              # ✅ Gateway API - Timeout
├── httproute-retry.yaml                # ✅ Gateway API - Retry (Istio 확장)
│
├── virtual-service-fault-injection.yaml # ⚠️ Istio 전용 - Fault Injection
├── destination-rule-circuit-breaker.yaml # ⚠️ Istio 전용 - Circuit Breaker
│
├── virtual-service-timeout.yaml         # (레거시) VirtualService Timeout
└── virtual-service-retry.yaml           # (레거시) VirtualService Retry
```

## 정리

```bash
kubectl delete -f .
```

## 학습 포인트

| 기능 | Gateway API | Istio 전용 | 사용 사례 |
|------|-------------|------------|----------|
| Timeout | ✅ HTTPRoute | VirtualService | 느린 서비스 연쇄 장애 방지 |
| Retry | ✅ HTTPRoute + 확장 | VirtualService | 일시적 오류 자동 복구 |
| Fault Injection | ❌ 미지원 | VirtualService | 카오스 엔지니어링 |
| Circuit Breaker | ❌ 미지원 | DestinationRule | 장애 격리, 연쇄 실패 방지 |

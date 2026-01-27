# Module 2: Resiliency (복원력)

## 목표
Istio를 사용하여 서비스의 복원력을 높이는 방법을 학습합니다.

## 실습 시나리오

### 시나리오 1: Timeout (타임아웃)

```bash
kubectl apply -f virtual-service-timeout.yaml

# 빠른 요청 (성공)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get

# 5초 지연 요청 (2초에 타임아웃)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/delay/5
```

### 시나리오 2: Retry (재시도)

```bash
kubectl apply -f virtual-service-retry.yaml

# 503 에러 (3회 재시도 후 실패)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/status/503
```

### 시나리오 3: Fault Injection (장애 주입)

```bash
kubectl apply -f virtual-service-fault-injection.yaml

# 일부 요청에 지연/에러 발생
for i in $(seq 1 10); do
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s -o /dev/null -w "%{http_code}\n" http://httpbin:8000/get
done
```

### 시나리오 4: Circuit Breaker (서킷 브레이커)

```bash
kubectl apply -f destination-rule-circuit-breaker.yaml

# 동시 요청으로 서킷 브레이커 트리거
for i in $(seq 1 5); do
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/delay/1 &
done
wait
```

## 정리

```bash
kubectl delete -f .
```

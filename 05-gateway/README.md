# Module 5: Gateway API

## 목표
Kubernetes Gateway API를 사용하여 외부 트래픽을 관리합니다.

## Gateway API vs Istio API

| 항목 | Istio API | Gateway API |
|------|-----------|-------------|
| Gateway | `networking.istio.io/Gateway` | `gateway.networking.k8s.io/Gateway` |
| 라우팅 | `VirtualService` | `HTTPRoute` |
| 표준화 | Istio 전용 | Kubernetes 표준 |
| 호환성 | Istio만 | Istio, Envoy Gateway, Kong 등 |

## 사전 준비

```bash
# Gateway API CRD 설치 (이미 설치된 경우 스킵)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Backend 서비스 배포
kubectl apply -f ../01-traffic-management/backend-v1.yaml
kubectl apply -f ../01-traffic-management/backend-v2.yaml
kubectl apply -f backend-v1-service.yaml
kubectl apply -f backend-v2-service.yaml
```

## 실습 시나리오

### 시나리오 1: Gateway 리소스 생성

```bash
kubectl apply -f gateway.yaml

# Gateway 상태 확인
kubectl get gateway demo-gateway -n istio-demo
```

### 시나리오 2: 기본 라우팅 (HTTPRoute)

```bash
kubectl apply -f httproute-basic.yaml

# 테스트 (Gateway를 통한 접근)
# Gateway Pod IP 확인 후 curl
```

### 시나리오 3: 가중치 기반 라우팅

```bash
kubectl apply -f httproute-canary.yaml
```

### 시나리오 4: 헤더 기반 라우팅

```bash
kubectl apply -f httproute-header.yaml
```

## 정리

```bash
kubectl delete -f .
```

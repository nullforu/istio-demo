# Module 3: Security (보안)

## 목표
Authorization Policy를 사용하여 서비스 간 접근 제어를 구현합니다.

## 실습 시나리오

### 시나리오 1: 모든 트래픽 차단 (DENY)

```bash
kubectl apply -f authorization-policy-deny-all.yaml

# 요청 차단됨 (403)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get

# 정리
kubectl delete -f authorization-policy-deny-all.yaml
```

### 시나리오 2: 특정 서비스만 허용 (ALLOW)

```bash
kubectl apply -f authorization-policy-allow-sleep.yaml

# sleep에서 요청 (허용)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get

# 정리
kubectl delete -f authorization-policy-allow-sleep.yaml
```

### 시나리오 3: 경로/메서드별 접근 제어

```bash
kubectl apply -f authorization-policy-path-based.yaml

# GET /get (허용)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://httpbin:8000/get

# POST /post (차단)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s -X POST http://httpbin:8000/post
```

## 정리

```bash
kubectl delete -f .
```

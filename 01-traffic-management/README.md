# Module 1: Traffic Management (트래픽 관리)

## 목표
VirtualService와 DestinationRule을 사용하여 트래픽을 제어하는 방법을 학습합니다.

## 사전 준비

```bash
# Backend v1, v2 배포
kubectl apply -f backend-v1.yaml
kubectl apply -f backend-v2.yaml
kubectl apply -f backend-service.yaml

# DestinationRule 적용 (서비스 버전 정의)
kubectl apply -f destination-rule.yaml
```

## 실습 시나리오

### 시나리오 1: Canary 배포 (가중치 기반 라우팅)

**개념**: 새 버전을 일부 트래픽에만 노출하여 안전하게 테스트

```bash
# Canary 설정 적용 (90% v1, 10% v2)
kubectl apply -f virtual-service-canary.yaml

# 테스트 (10번 중 약 1번 v2 응답)
for i in $(seq 1 10); do
  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://backend:8080
done
```

### 시나리오 2: 헤더 기반 라우팅

**개념**: 특정 헤더가 있는 요청만 새 버전으로 라우팅

```bash
# 헤더 기반 라우팅 적용
kubectl apply -f virtual-service-header.yaml

# 일반 요청 (→ v1)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://backend:8080

# x-version: v2 헤더 (→ v2)
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s -H "x-version: v2" http://backend:8080
```

### 시나리오 3: 트래픽 미러링

**개념**: 프로덕션 트래픽을 새 버전으로 복제하여 테스트 (응답은 무시)

```bash
# 미러링 적용 (v1으로 응답, v2로 복제)
kubectl apply -f virtual-service-mirror.yaml

# 요청 전송
kubectl exec -n istio-demo deploy/sleep -c sleep -- curl -s http://backend:8080

# v2 로그에서 미러링된 요청 확인
kubectl logs -n istio-demo deploy/backend-v2 -c backend --tail=5
```

## 정리

```bash
kubectl delete -f .
```

## 학습 포인트

| 기능 | 사용 사례 |
|------|----------|
| 가중치 라우팅 | Canary 배포, A/B 테스트 |
| 헤더 라우팅 | Beta 사용자, QA 테스트 |
| 미러링 | Shadow 테스트, 성능 검증 |

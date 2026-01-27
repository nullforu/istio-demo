# Istio Demo 테스트 시나리오

각 모듈별 테스트 스크립트와 시나리오입니다.

## 디렉토리 구조

```
tests/
├── README.md                    # 이 문서
├── 00-setup-test.sh            # 환경 설정 확인
├── 01-observability-test.sh    # 관측성 테스트 (Jaeger, Prometheus, Grafana)
├── 02-traffic-test.sh          # 트래픽 관리 테스트 (Canary, Header Routing)
├── 03-resiliency-test.sh       # 복원력 테스트 (Timeout, Retry, Circuit Breaker)
├── 04-security-test.sh         # 보안 테스트 (Authorization Policy)
└── 05-gateway-test.sh          # Gateway API 테스트
```

## 실행 순서

```bash
# 1. 환경 확인
./00-setup-test.sh

# 2. 관측성 테스트 (가장 먼저!)
./01-observability-test.sh

# 3. 트래픽 관리 테스트
./02-traffic-test.sh

# 4. 복원력 테스트
./03-resiliency-test.sh

# 5. 보안 테스트
./04-security-test.sh

# 6. Gateway API 테스트
./05-gateway-test.sh
```

## 사전 요구사항

- Kind 클러스터 실행 중
- Istio 설치 완료
- 샘플 애플리케이션 배포 완료

```bash
# 클러스터 확인
kubectl config current-context  # kind-istio-demo

# Pod 상태 확인
kubectl get pods -n istio-demo
```

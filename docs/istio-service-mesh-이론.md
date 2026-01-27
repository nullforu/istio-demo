# Istio Service Mesh 완벽 가이드

> 마이크로서비스 간 통신을 대신 관리해주는 인프라 레이어

---

## 목차

1. [Service Mesh가 뭔가요?](#1-service-mesh가-뭔가요)
2. [Istio 핵심 개념](#2-istio-핵심-개념)
3. [관측성 (Observability)](#3-관측성-observability)
4. [트래픽 관리](#4-트래픽-관리)
5. [복원력 (Resiliency)](#5-복원력-resiliency)
6. [보안](#6-보안)
7. [Gateway API](#7-gateway-api)

---

## 1. Service Mesh가 뭔가요?

> 서비스들 사이의 네트워크 통신을 애플리케이션 대신 처리해주는 인프라

쉽게 말해서, **서비스들의 교통 경찰**이라고 생각하면 편함. 누가 어디로 가는지, 얼마나 빨리 가는지, 문제가 생기면 어떻게 할지 다 관리해주는 거임.

### 왜 필요할까?

마이크로서비스가 많아지면 이런 고민이 생김:

- **통신 복잡도 폭발**: 서비스가 10개면 잠재적 통신 경로가 90개 (n × (n-1))
- **어디서 느린지 모름**: 요청이 A → B → C → D를 거쳐가면, 어디서 병목인지 찾기 어려움
- **장애 전파**: 하나가 죽으면 연쇄적으로 다 죽음
- **보안**: 서비스끼리 통신할 때 암호화는 누가 할 건데?
- **배포 부담**: 새 버전 배포할 때 트래픽 조절은?

이걸 각 서비스 코드에서 처리하려면 모든 서비스에 같은 로직을 넣어야 함. **비즈니스 로직과 인프라 로직이 섞이는 거임**.

### Service Mesh의 해결책

인프라 로직을 애플리케이션 밖으로 빼는 거임:

| 기존 방식 | Service Mesh |
|----------|--------------|
| 각 서비스에서 재시도 로직 구현 | 설정 파일 한 줄로 해결 |
| 각 서비스에서 타임아웃 처리 | 메시에서 일괄 적용 |
| 각 서비스에서 TLS 인증서 관리 | 자동으로 mTLS 적용 |
| 분산 추적 라이브러리 설치 | 자동으로 수집 |

### Sidecar 패턴

> 모든 서비스 옆에 작은 프록시를 하나씩 붙여놓는 방식

오토바이 옆에 붙은 사이드카라고 생각하면 편함. 본체(애플리케이션)는 달리는 것만 신경 쓰고, 사이드카(프록시)가 짐 싣고 지도 보고 다 해주는 거임.

```text
┌─────────────────────────────────────┐
│  Pod                                 │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Application  │──│ Envoy Proxy  │ │
│  │ (내 코드)     │  │ (사이드카)    │ │
│  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────┘
              │
              ▼ 모든 트래픽이 프록시를 통과
```

- 애플리케이션은 프록시가 있는지도 모름
- 프록시끼리 협력해서 트래픽 관리, 보안, 모니터링 처리
- 애플리케이션 코드 수정 없이 기능 추가 가능

---

## 2. Istio 핵심 개념

> Istio = Service Mesh를 구현한 오픈소스 플랫폼

Istio는 크게 두 부분으로 나뉨:

### Control Plane vs Data Plane

| 구분 | 역할 | 구성요소 |
|------|------|----------|
| **Control Plane** | 정책 결정, 설정 배포 | istiod |
| **Data Plane** | 실제 트래픽 처리 | Envoy Proxy (사이드카) |

- **Control Plane**: 두뇌라고 생각하면 편함. "A 서비스 트래픽 중 10%는 B로 보내" 같은 명령을 내림
- **Data Plane**: 손발임. 실제로 트래픽을 잡아서 라우팅하고, 암호화하고, 메트릭 수집

```text
                  ┌───────────────────┐
                  │     istiod        │
                  │  (Control Plane)  │
                  └─────────┬─────────┘
                            │ 설정 배포
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
    ┌──────────┐      ┌──────────┐      ┌──────────┐
    │ Envoy    │ ─────│ Envoy    │ ─────│ Envoy    │
    │ (Pod A)  │      │ (Pod B)  │      │ (Pod C)  │
    └──────────┘      └──────────┘      └──────────┘
         └──────────────────────────────────┘
                     Data Plane
```

### Envoy Proxy

> Lyft에서 만든 고성능 프록시

Istio가 사이드카로 사용하는 실제 프록시임. 특징:

- C++로 작성되어 빠름
- 동적 설정 변경 가능 (재시작 없이)
- L4/L7 모두 처리
- 풍부한 메트릭 자동 수집

### 주요 CRD (Custom Resource Definitions)

Istio를 쓰려면 이 네 가지 리소스를 알아야 함:

#### VirtualService

> 트래픽을 어디로 보낼지 결정하는 라우팅 규칙

"backend 서비스로 가는 요청을 v1과 v2에 나눠서 보내" 같은 규칙을 정의함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: istio-demo
spec:
  hosts:
    - backend          # 이 서비스로 가는 트래픽에 대해
  http:
    - route:
        - destination:
            host: backend
            subset: v1   # 90%는 v1으로
          weight: 90
        - destination:
            host: backend
            subset: v2   # 10%는 v2로
          weight: 10
```

#### DestinationRule

> 목적지(서비스)의 버전 정의와 로드밸런싱 정책

VirtualService가 "어디로 보낼지"라면, DestinationRule은 "그게 정확히 뭔지" 정의함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-destination
  namespace: istio-demo
spec:
  host: backend
  subsets:            # "v1", "v2"가 정확히 어떤 Pod인지 정의
    - name: v1
      labels:
        version: v1   # version=v1 라벨을 가진 Pod
    - name: v2
      labels:
        version: v2   # version=v2 라벨을 가진 Pod
```

#### AuthorizationPolicy

> 누가 어떤 서비스에 접근할 수 있는지 결정

방화벽이라고 생각하면 편함. "이 서비스는 저 서비스만 호출 가능" 같은 규칙.

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-sleep-only
  namespace: istio-demo
spec:
  selector:
    matchLabels:
      app: httpbin         # httpbin 서비스에 대해
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/istio-demo/sa/sleep"]
            # sleep 서비스만 접근 허용
```

#### Gateway

> 외부 트래픽의 진입점

클러스터 밖에서 들어오는 요청을 받아주는 문임.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-gateway
  namespace: istio-demo
spec:
  gatewayClassName: istio   # Istio가 이 Gateway 관리
  listeners:
    - name: http
      port: 80
      protocol: HTTP
```

---

## 3. 관측성 (Observability)

> 분산 시스템에서 "지금 무슨 일이 일어나고 있는지" 파악하는 능력

마이크로서비스가 많아지면 "어디서 문제인지" 찾기가 정말 어려움. Istio는 이걸 자동으로 해결해줌.

### 관측성의 3대 축

| 축 | 설명 | 도구 |
|----|------|------|
| **로깅(Logging)** | 개별 이벤트 기록 | ELK, Loki |
| **메트릭(Metrics)** | 수치 데이터 (QPS, 지연시간) | Prometheus + Grafana |
| **트레이싱(Tracing)** | 요청 흐름 추적 | Jaeger, Zipkin |

### Kiali - 서비스 그래프 시각화

> 서비스들의 관계와 트래픽 흐름을 그래프로 보여줌

- 어떤 서비스가 어떤 서비스를 호출하는지 한눈에
- 트래픽 양, 에러율, 지연시간 실시간 확인
- 문제 있는 서비스는 빨간색으로 표시

접속: `http://localhost:20001`

### Jaeger - 분산 추적

> 하나의 요청이 여러 서비스를 거치는 전체 경로를 추적

"이 API 요청이 왜 느리지?"를 찾을 때 필수임.

- 요청 하나가 A → B → C를 거쳤다면, 각 구간별 소요 시간 확인
- 어디서 병목인지 바로 파악
- Istio가 자동으로 trace 정보 수집 (애플리케이션 코드 수정 최소화)

접속: `http://localhost:16686`

### Prometheus + Grafana - 메트릭

- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 대시보드로 시각화

Istio가 자동으로 수집하는 메트릭:

- `istio_requests_total`: 총 요청 수
- `istio_request_duration_milliseconds`: 요청 처리 시간
- `istio_request_bytes`: 요청 크기
- `istio_response_bytes`: 응답 크기

접속:

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`

### OpenTelemetry (OTEL) - 관측성 표준

> 벤더 중립적인 관측성 데이터 수집 표준

Jaeger, Prometheus, Zipkin 등 도구가 제각각 데이터 형식을 쓰면 곤란함. OpenTelemetry는 이걸 통일한 표준임.

#### Signal (시그널)

OTEL이 수집하는 세 가지 데이터 타입:

| Signal | 설명 | 예시 |
|--------|------|------|
| **Traces** | 요청의 전체 경로 추적 | A → B → C 서비스 호출 흐름 |
| **Metrics** | 수치 데이터 | 요청 수, 지연 시간, 에러율 |
| **Logs** | 개별 이벤트 기록 | 에러 메시지, 디버그 정보 |

세 시그널을 **상관관계(correlation)**로 묶을 수 있는 게 OTEL의 핵심임. "이 에러 로그가 어떤 trace에서 발생했는지" 추적 가능.

#### Instrumentation (계측)

> 애플리케이션에서 시그널 데이터를 수집하는 방법

두 가지 방식이 있음:

- **Auto Instrumentation**: 코드 수정 없이 자동 수집
  - Istio 사이드카가 자동으로 trace 정보 주입
  - 대부분의 HTTP/gRPC 호출 자동 추적
- **Manual Instrumentation**: 코드에 직접 SDK 추가
  - 비즈니스 로직 내부 span 추가
  - 커스텀 메트릭 정의

Istio + OTEL Collector 조합:

```text
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Application │ ──▶ │   Envoy     │ ──▶ │    OTEL     │ ──▶ Jaeger, Prometheus
│             │     │  (사이드카)  │     │  Collector  │
└─────────────┘     └─────────────┘     └─────────────┘
                    Auto Instrumentation
```

- Envoy가 자동으로 trace header 전파
- OTEL Collector가 데이터 수집/변환/전송
- 백엔드(Jaeger, Prometheus)로 라우팅

#### 데이터베이스 Auto Instrumentation

OpenTelemetry는 데이터베이스 클라이언트 라이브러리도 자동 계측 가능함:

| 데이터베이스 | Python 라이브러리 | OTEL Instrumentation |
|-------------|------------------|---------------------|
| Redis | `redis-py` | `opentelemetry-instrumentation-redis` |
| MongoDB | `pymongo` | `opentelemetry-instrumentation-pymongo` |
| PostgreSQL | `psycopg2` | `opentelemetry-instrumentation-psycopg2` |
| MySQL | `mysql-connector` | `opentelemetry-instrumentation-mysql` |

자동으로 캡처되는 정보:

- **Redis**: 명령어(SET, GET, INCR), 키 이름
- **MongoDB**: 작업 유형(insert, find, aggregate), 컬렉션 이름, 쿼리 필터

```python
# 코드 수정 없이 한 줄로 활성화
from opentelemetry.instrumentation.pymongo import PymongoInstrumentor
PymongoInstrumentor().instrument()

# 이후 모든 MongoDB 작업이 자동으로 span 생성
db.users.find({"name": "kim"})  # → 'pymongo.find' span 자동 생성
```

---

## 4. 트래픽 관리

> 서비스로 가는 트래픽을 세밀하게 제어

### Canary 배포 (점진적 배포)

> 새 버전을 소수의 사용자에게만 먼저 배포하는 방식

광산에서 카나리아 새를 먼저 보내서 가스 확인하듯이, 새 버전을 일부 트래픽으로만 먼저 테스트함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: istio-demo
spec:
  hosts:
    - backend
  http:
    - route:
        - destination:
            host: backend
            subset: v1
          weight: 90    # 90%는 안정된 v1
        - destination:
            host: backend
            subset: v2
          weight: 10    # 10%만 새 버전 v2
```

점진적 배포 단계:

| 일차 | v1 | v2 |
|------|----|----|
| 1일차 | 90% | 10% |
| 2일차 | 70% | 30% (문제 없으면) |
| 3일차 | 50% | 50% |
| 4일차 | 0% | 100% (완전 전환) |

### 헤더 기반 라우팅

> 특정 헤더 값에 따라 다른 버전으로 라우팅

QA팀이나 Beta 테스터만 새 버전 접근하게 할 때 유용함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: istio-demo
spec:
  hosts:
    - backend
  http:
    - match:
        - headers:
            x-version:
              exact: "v2"      # 이 헤더가 있으면
      route:
        - destination:
            host: backend
            subset: v2         # v2로
    - route:
        - destination:
            host: backend
            subset: v1         # 기본은 v1
```

사용 예:

```bash
# 일반 사용자: v1으로 감
curl backend:8080

# Beta 테스터: v2로 감
curl -H "x-version: v2" backend:8080
```

### 트래픽 미러링 (Shadow 테스트)

> 실제 트래픽을 복제해서 새 버전으로 보내되, 응답은 무시

프로덕션 트래픽으로 새 버전을 테스트하고 싶은데, 실제 사용자에게 영향 주기 싫을 때 사용함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: istio-demo
spec:
  hosts:
    - backend
  http:
    - route:
        - destination:
            host: backend
            subset: v1         # 응답은 v1에서만
      mirror:
        host: backend
        subset: v2             # v2로도 복제
      mirrorPercentage:
        value: 100.0           # 100% 복제
```

- 사용자 요청은 v1이 처리하고 응답
- 같은 요청이 v2로도 가지만, v2의 응답은 버려짐
- v2의 로그와 메트릭으로 문제 없는지 확인

---

## 5. 복원력 (Resiliency)

> 장애가 발생해도 시스템이 견디는 능력

분산 시스템에서는 장애가 **반드시** 발생함. 중요한 건 장애를 예방하는 게 아니라, 장애에도 버티는 것.

### Timeout - 무한 대기 방지

> 응답이 없으면 일정 시간 후 포기

하나의 느린 서비스 때문에 전체가 멈추는 걸 방지함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-timeout
  namespace: istio-demo
spec:
  hosts:
    - httpbin
  http:
    - timeout: 2s    # 2초 내 응답 없으면 504 반환
      route:
        - destination:
            host: httpbin
```

- 설정 없으면: 클라이언트가 무한정 대기 → 리소스 고갈
- 설정 있으면: 2초 후 빠르게 실패 → 다른 작업 처리 가능

### Retry - 일시적 오류 극복

> 실패하면 자동으로 다시 시도

네트워크 일시 불안정, 서비스 재시작 중 등 일시적 문제는 재시도로 해결 가능함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-retry
  namespace: istio-demo
spec:
  hosts:
    - httpbin
  http:
    - retries:
        attempts: 3         # 최대 3회 재시도
        perTryTimeout: 1s   # 각 시도당 1초 타임아웃
        retryOn: 5xx        # 5xx 에러일 때만 재시도
      route:
        - destination:
            host: httpbin
```

주의사항:

- **멱등(Idempotent)한 요청에만** 사용해야 함
- POST로 결제하는 API에 재시도하면 중복 결제될 수 있음

### Fault Injection - 카오스 엔지니어링

> 일부러 장애를 주입해서 시스템 복원력 테스트

"서비스 B가 느려지면 우리 시스템은 어떻게 될까?"를 실제로 테스트함.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin-fault
  namespace: istio-demo
spec:
  hosts:
    - httpbin
  http:
    - fault:
        delay:
          percentage:
            value: 50        # 50% 요청에
          fixedDelay: 2s     # 2초 지연 주입
        abort:
          percentage:
            value: 10        # 10% 요청에
          httpStatus: 500    # 500 에러 주입
      route:
        - destination:
            host: httpbin
```

- 프로덕션 배포 전에 장애 상황 미리 경험
- Timeout, Retry, Circuit Breaker가 제대로 동작하는지 확인

### Circuit Breaker - 과부하 차단

> 장애가 발생한 서비스로의 요청을 차단

전기 회로의 차단기(breaker)라고 생각하면 편함. 과부하되면 회로를 끊어서 화재 방지하듯이, 장애 서비스로의 요청을 끊어서 연쇄 장애 방지.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-circuit-breaker
  namespace: istio-demo
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1           # 동시 연결 1개 제한
      http:
        http1MaxPendingRequests: 1  # 대기 요청 1개 제한
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 3       # 연속 3회 5xx 에러 발생 시
      interval: 10s                 # 10초마다 검사
      baseEjectionTime: 30s         # 30초간 해당 Pod 제외
      maxEjectionPercent: 100       # 최대 100% Pod 제외 가능
```

동작 방식:

1. 정상 상태 (Closed): 요청 정상 처리
2. 에러 감지: 연속 5xx 에러 발생
3. 차단 상태 (Open): 해당 Pod으로 요청 안 보냄 (즉시 503 반환)
4. 반개방 (Half-Open): 일정 시간 후 일부 요청 시도
5. 복구되면 → 정상 상태로 복귀

---

## 6. 보안

> 서비스 간 통신의 인증, 인가, 암호화

### mTLS - 서비스 간 암호화 통신

> 양방향 TLS 인증 (mutual TLS)

일반 TLS는 클라이언트가 서버를 검증하지만, mTLS는 서버도 클라이언트를 검증함.

- Istio가 자동으로 인증서 발급 및 교체
- 애플리케이션 코드 수정 없이 모든 통신 암호화
- 서비스 간 신원 확인 (이 요청이 정말 A 서비스에서 온 건지)

Istio는 기본적으로 `PERMISSIVE` 모드로 동작함:

- mTLS 가능하면 mTLS 사용
- 안 되면 평문 통신도 허용

엄격하게 하려면:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-demo
spec:
  mtls:
    mode: STRICT   # mTLS만 허용, 평문 통신 거부
```

### AuthorizationPolicy - 접근 제어

> "누가 어떤 서비스에 어떤 행동을 할 수 있는지" 정의

기본 패턴: **DENY ALL → ALLOW 필요한 것만**

#### 1단계: 모든 접근 차단

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: istio-demo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: DENY
  rules:
    - {}   # 모든 요청 거부
```

#### 2단계: 필요한 접근만 허용

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-sleep-only
  namespace: istio-demo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/istio-demo/sa/sleep"]
            # sleep 서비스의 ServiceAccount만 허용
```

### 세분화된 접근 제어

경로(path)와 메서드(method)별로도 제어 가능함:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: path-based
  namespace: istio-demo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/istio-demo/sa/sleep"]
      to:
        - operation:
            methods: ["GET"]        # GET만 허용
            paths: ["/get", "/ip"]  # 이 경로만 허용
```

- `/get`에 GET 요청: 허용
- `/post`에 POST 요청: 거부 (403)
- `/get`에 POST 요청: 거부 (403)

---

## 7. Gateway API

> Kubernetes 공식 Ingress 후속작

### Istio API vs Gateway API

| 구분 | Istio API | Gateway API |
|------|-----------|-------------|
| 표준화 | Istio 전용 | Kubernetes SIG-Network 표준 |
| 이식성 | Istio에서만 동작 | Istio, Envoy Gateway, Traefik 등 |
| 리소스 | VirtualService, Gateway | HTTPRoute, Gateway |
| 미래 | 유지보수 | Kubernetes 공식 방향 |

### 왜 Gateway API를 쓰나?

- **벤더 중립성**: Istio 말고 다른 구현체로 바꿔도 설정 재사용
- **표준화**: Kubernetes 커뮤니티가 관리
- **역할 분리**: 인프라팀(Gateway)과 개발팀(HTTPRoute) 분리 가능
- **미래 지향**: Ingress의 한계를 넘어선 차세대 표준

### 기본 구조

Gateway API는 두 리소스로 나뉨:

#### Gateway - 인프라팀이 관리

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-gateway
  namespace: istio-demo
spec:
  gatewayClassName: istio      # Istio가 처리
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same           # 같은 네임스페이스의 Route만 허용
```

#### HTTPRoute - 개발팀이 관리

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-route
  namespace: istio-demo
spec:
  parentRefs:
    - name: demo-gateway       # 어떤 Gateway에 붙을지
  hostnames:
    - "httpbin.local"          # 이 호스트명으로 오면
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: httpbin        # httpbin 서비스로
          port: 8000
```

### Istio VirtualService vs Gateway API HTTPRoute

같은 기능, 다른 문법:

#### Canary 배포 (Istio VirtualService)

```yaml
spec:
  http:
    - route:
        - destination:
            host: backend
            subset: v1
          weight: 90
        - destination:
            host: backend
            subset: v2
          weight: 10
```

#### Canary 배포 (Gateway API HTTPRoute)

```yaml
spec:
  rules:
    - backendRefs:
        - name: backend-v1
          port: 8080
          weight: 90
        - name: backend-v2
          port: 8080
          weight: 10
```

Gateway API에서는 subset 대신 별도 Service를 사용하는 게 일반적임.

---

## 정리

| 영역 | Istio 해결책 | 핵심 리소스 |
|------|-------------|-------------|
| 트래픽 라우팅 | Canary, 헤더 기반, 미러링 | VirtualService |
| 버전 정의 | Subset, 로드밸런싱 | DestinationRule |
| 복원력 | Timeout, Retry, Circuit Breaker | VirtualService, DestinationRule |
| 보안 | mTLS, 접근 제어 | AuthorizationPolicy, PeerAuthentication |
| 관측성 | 자동 메트릭, 추적 | Telemetry (기본 활성화) |
| 외부 트래픽 | Gateway API 지원 | Gateway, HTTPRoute |

> Service Mesh는 "마이크로서비스 간 통신"이라는 횡단 관심사(cross-cutting concern)를 애플리케이션에서 분리한 것

비즈니스 로직에만 집중하고, 나머지는 인프라에 맡기면 됨. 그게 Service Mesh의 핵심임.

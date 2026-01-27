# Istio Demo Project Overview

## 프로젝트 구조

```mermaid
flowchart TB
    subgraph root["istio-demo/"]
        README["README.md"]
        CLAUDE["CLAUDE.md"]

        subgraph setup["00-setup/"]
            install["install.sh"]
            kind["kind-config.yaml"]
            istio["istio-operator.yaml"]
            subgraph apps["sample-app/"]
                httpbin["httpbin.yaml"]
                sleep["sleep.yaml"]
                demoapp["demo-app/"]
            end
        end

        subgraph modules["실습 모듈"]
            m1["01-traffic-management/"]
            m2["02-resiliency/"]
            m3["03-security/"]
            m4["04-observability/"]
            m5["05-gateway/"]
        end

        subgraph support["지원 도구"]
            tests["tests/"]
            notebooks["notebooks/"]
            docs["docs/"]
        end
    end

    setup --> modules
    modules --> support
```

## Kubernetes 네임스페이스 구조

```mermaid
flowchart LR
    subgraph cluster["Kind Cluster: istio-demo"]
        subgraph istio-system["istio-system"]
            istiod["istiod<br/>(Control Plane)"]
            ingressgw["istio-ingressgateway"]
        end

        subgraph istio-demo["istio-demo"]
            httpbin["httpbin"]
            sleep["sleep"]
            backend-v1["backend-v1"]
            backend-v2["backend-v2"]
            demo-app["demo-app"]
            redis["redis"]
            mongodb["mongodb"]
        end

        subgraph observability["observability"]
            jaeger["Jaeger"]
            kiali["Kiali"]
        end

        subgraph monitoring["monitoring"]
            prometheus["Prometheus"]
            grafana["Grafana"]
            otel["OTEL Collector"]
        end
    end

    istiod -.->|sidecar injection| istio-demo
    istio-demo -->|traces| jaeger
    istio-demo -->|metrics| prometheus
    kiali -->|query| prometheus
    kiali -->|query| jaeger
```

## Istio 아키텍처

```mermaid
flowchart TB
    subgraph "Data Plane"
        subgraph pod1["Pod: sleep"]
            app1["sleep container"]
            envoy1["Envoy Sidecar"]
        end

        subgraph pod2["Pod: httpbin"]
            app2["httpbin container"]
            envoy2["Envoy Sidecar"]
        end

        subgraph pod3["Pod: backend-v1"]
            app3["backend container"]
            envoy3["Envoy Sidecar"]
        end
    end

    subgraph "Control Plane"
        istiod["istiod"]
    end

    subgraph "Istio CRDs"
        vs["VirtualService"]
        dr["DestinationRule"]
        gw["Gateway"]
        ap["AuthorizationPolicy"]
    end

    app1 --> envoy1
    envoy1 -->|mTLS| envoy2
    envoy1 -->|mTLS| envoy3

    istiod -->|config push| envoy1
    istiod -->|config push| envoy2
    istiod -->|config push| envoy3

    vs --> istiod
    dr --> istiod
    gw --> istiod
    ap --> istiod
```

## 실습 모듈 흐름

```mermaid
flowchart LR
    subgraph M0["Module 0<br/>Setup"]
        m0a["Kind 클러스터"]
        m0b["Istio 설치"]
        m0c["샘플 앱 배포"]
    end

    subgraph M4["Module 4<br/>Observability"]
        m4a["Kiali"]
        m4b["Jaeger"]
        m4c["Grafana"]
    end

    subgraph M1["Module 1<br/>Traffic"]
        m1a["Canary 배포"]
        m1b["헤더 라우팅"]
        m1c["트래픽 미러링"]
    end

    subgraph M2["Module 2<br/>Resiliency"]
        m2a["Timeout"]
        m2b["Retry"]
        m2c["Circuit Breaker"]
    end

    subgraph M3["Module 3<br/>Security"]
        m3a["deny-all"]
        m3b["allow 정책"]
        m3c["path 기반"]
    end

    subgraph M5["Module 5<br/>Gateway API"]
        m5a["Gateway"]
        m5b["HTTPRoute"]
    end

    M0 --> M4 --> M1 --> M2 --> M3 --> M5
```

## 컴포넌트 스택

```mermaid
block-beta
    columns 3

    block:infra:3
        kind["Kind v0.25.0"]
        k8s["Kubernetes v1.31.2"]
    end

    block:mesh:3
        istio["Istio 1.24.3"]
    end

    block:observe:3
        jaeger["Jaeger 4.4.2"]
        kiali["Kiali 2.20.0"]
        otel["OTEL 0.144.0"]
    end

    block:monitor:3
        prom["Prometheus"]
        grafana["Grafana"]
    end

    block:apps:3
        httpbin["httpbin"]
        sleep["sleep"]
        backend["backend v1/v2"]
        demoapp["demo-app"]
    end
```

## 트래픽 흐름

```mermaid
sequenceDiagram
    participant U as User/Client
    participant IG as Istio Ingress
    participant E1 as Envoy (sleep)
    participant E2 as Envoy (httpbin)
    participant App as httpbin App

    U->>IG: HTTP Request
    IG->>E1: Route to Pod
    E1->>E2: mTLS encrypted
    E2->>App: Local call
    App-->>E2: Response
    E2-->>E1: mTLS encrypted
    E1-->>IG: Response
    IG-->>U: HTTP Response

    Note over E1,E2: Envoy sidecars handle<br/>routing, security, telemetry
```

## 주요 포트 매핑

| 서비스 | 내부 포트 | 외부 포트 | 용도 |
|--------|-----------|-----------|------|
| Kiali | 20001 | 20001 | Service Mesh 시각화 |
| Jaeger | 16686 | 16686 | 분산 트레이싱 UI |
| Grafana | 80 | 3000 | 메트릭 대시보드 |
| Prometheus | 9090 | 9090 | 메트릭 쿼리 |
| Ingress | 80 | 31080 | 외부 트래픽 진입점 |

## 파일 구조 요약

| 디렉토리 | 파일 유형 | 설명 |
|----------|-----------|------|
| `00-setup/` | YAML, Shell | 클러스터 및 Istio 설치 |
| `01-traffic-management/` | YAML | VirtualService, DestinationRule |
| `02-resiliency/` | YAML | Timeout, Retry, Circuit Breaker |
| `03-security/` | YAML | AuthorizationPolicy |
| `04-observability/` | YAML | Gateway 설정 (UI 접근용) |
| `05-gateway/` | YAML | Gateway API 리소스 |
| `tests/` | Shell | 각 모듈별 검증 스크립트 |
| `notebooks/` | ipynb | 한국어 실습 가이드 |

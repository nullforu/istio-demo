# 📚 Istio Service Mesh 실습

> 쿠버네티스 환경에서 Istio를 직접 설치하고, 트래픽 관리/복원력/보안/관측성을 실습합니다.

## 📖 먼저 읽어주세요

실습 전 Istio의 핵심 개념을 먼저 이해하세요:

**👉 [Istio Service Mesh 이론](docs/istio-service-mesh-이론.md)**

## 🛠 사전 요구사항

| 도구 | 버전 | 확인 명령어 |
|------|------|-------------|
| Docker | 20.10+ | `docker --version` |
| kubectl | 1.28+ | `kubectl version --client` |
| Helm | 3.0+ | `helm version` |

## 🚀 빠른 시작

```bash
cd 00-setup && ./install.sh
kubectl get pods -n istio-system
```

## ⚠️ Security Notice

This is an **educational demo** project. The following configurations are intentionally simplified for learning purposes:

- Grafana: `admin/admin` default credentials
- Kiali: Anonymous authentication enabled
- TLS: Disabled for internal telemetry
- Security contexts: Not configured

**DO NOT use these configurations in production environments.**

## 📖 학습 순서

관측성 도구(Kiali, Jaeger)를 먼저 설정해두면 이후 실습 결과를 시각적으로 확인할 수 있습니다.

| 순서 | 모듈 | 배우는 것 | 폴더 |
|------|------|----------|------|
| 0 | 환경 세팅 | Kind 클러스터, Istio 설치 | [00-setup](00-setup/) |
| 1 | **관측성** | Kiali, Jaeger, Grafana | [04-observability](04-observability/) |
| 2 | 트래픽 관리 | Canary 배포, 헤더 라우팅, 미러링 | [01-traffic-management](01-traffic-management/) |
| 3 | 복원력 | Timeout, Retry, Circuit Breaker | [02-resiliency](02-resiliency/) |
| 4 | 보안 | mTLS, AuthorizationPolicy | [03-security](03-security/) |
| 5 | Gateway API | Gateway, HTTPRoute | [05-gateway](05-gateway/) |

**Jupyter Notebook 버전**: [notebooks/](notebooks/) 폴더에서 대화형으로 실습할 수 있습니다.

## 🖥 UI 접속

```bash
# Kiali (Service Graph)
kubectl port-forward -n observability svc/kiali 20001:20001
# → http://localhost:20001

# Jaeger (Distributed Tracing)
kubectl port-forward -n observability svc/jaeger 16686:16686
# → http://localhost:16686

# Grafana (Dashboard)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000 (admin/admin)

# Prometheus (Metrics)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090
```

## 🧹 정리

```bash
kind delete cluster --name istio-demo
```

## 📎 참고 자료

- [Istio 공식 문서](https://istio.io/latest/docs/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Kiali 문서](https://kiali.io/docs/)
- [Jaeger 문서](https://www.jaegertracing.io/docs/)

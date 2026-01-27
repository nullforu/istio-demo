# UI 접속 방법

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

## 클러스터 정리

```bash
kind delete cluster --name istio-demo
```

## 참고 자료

- [Istio 공식 문서](https://istio.io/latest/docs/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Kiali 문서](https://kiali.io/docs/)
- [Jaeger 문서](https://www.jaegertracing.io/docs/)

#!/bin/bash
set -e

echo "=========================================="
echo "Istio Demo Environment Setup"
echo "Date: 2026-01-26"
echo "=========================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 버전 정의 (2026-01-27 기준 최신)
ISTIO_VERSION="1.24.3"
KUBE_PROMETHEUS_VERSION="81.2.2"
JAEGER_VERSION="4.4.2"
OTEL_COLLECTOR_VERSION="0.144.0"
KIALI_VERSION="2.20.0"

echo -e "${YELLOW}[1/11] Creating Kind Cluster...${NC}"
if kind get clusters | grep -q "istio-demo"; then
    echo "Cluster 'istio-demo' already exists. Deleting..."
    kind delete cluster --name istio-demo
fi
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-istio-demo

echo -e "${YELLOW}[2/11] Creating Namespaces...${NC}"
kubectl apply -f namespace.yaml

echo -e "${YELLOW}[3/11] Adding Helm Repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add kiali https://kiali.org/helm-charts
helm repo update

echo -e "${YELLOW}[4/11] Installing kube-prometheus-stack (Prometheus + Grafana)...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --version ${KUBE_PROMETHEUS_VERSION} \
    --set prometheus.service.type=NodePort \
    --set prometheus.service.nodePort=31090 \
    --set grafana.service.type=NodePort \
    --set grafana.service.nodePort=31300 \
    --set grafana.adminPassword=admin \
    --wait --timeout 5m

echo -e "${YELLOW}[5/11] Installing Jaeger...${NC}"
helm upgrade --install jaeger jaegertracing/jaeger \
    --namespace observability \
    --version ${JAEGER_VERSION} \
    --set provisionDataStore.cassandra=false \
    --set allInOne.enabled=true \
    --set storage.type=memory \
    --set agent.enabled=false \
    --set collector.enabled=false \
    --set query.enabled=false \
    --wait --timeout 3m

echo -e "${YELLOW}[6/11] Installing OpenTelemetry Collector...${NC}"
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
    --namespace observability \
    --version ${OTEL_COLLECTOR_VERSION} \
    -f otel-collector-values.yaml \
    --wait --timeout 3m

echo -e "${YELLOW}[7/11] Installing Kiali...${NC}"
helm upgrade --install kiali-server kiali/kiali-server \
    --namespace observability \
    --version ${KIALI_VERSION} \
    -f kiali-values.yaml \
    --wait --timeout 3m

echo -e "${YELLOW}[8/11] Installing Istio with istioctl...${NC}"
if ! command -v istioctl &> /dev/null; then
    echo "Installing istioctl..."
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
    export PATH="$PWD/istio-${ISTIO_VERSION}/bin:$PATH"
fi

istioctl install -f istio-operator.yaml -y
kubectl label namespace istio-demo istio-injection=enabled --overwrite

echo -e "${YELLOW}[9/11] Applying Telemetry Configuration...${NC}"
kubectl apply -f telemetry.yaml

echo -e "${YELLOW}[10/11] Applying Istio Prometheus ServiceMonitor...${NC}"
kubectl apply -f prometheus-istio-servicemonitor.yaml

echo -e "${YELLOW}[11/11] Downloading and Applying Istio Grafana Dashboards...${NC}"
ISTIO_DASHBOARDS_URL="https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION%.*}/manifests/addons/dashboards"
DASHBOARD_DIR=$(mktemp -d)

download_success=0
download_failed=0

for entry in "istio-mesh-dashboard:7639" "istio-service-dashboard:7636" "istio-workload-dashboard:7630" "istio-performance-dashboard:7645"; do
    dashboard="${entry%:*}"
    grafana_id="${entry#*:}"
    echo "  Downloading ${dashboard}..."
    json_file="${DASHBOARD_DIR}/${dashboard}.json"

    if curl -sfL "${ISTIO_DASHBOARDS_URL}/${dashboard}.json" -o "${json_file}" 2>/dev/null && [ -s "${json_file}" ]; then
        echo -e "    ${GREEN}✓ Downloaded from Istio GitHub${NC}"
        download_success=$((download_success + 1))
    elif curl -sfL "https://grafana.com/api/dashboards/${grafana_id}/revisions/latest/download" -o "${json_file}" 2>/dev/null && [ -s "${json_file}" ]; then
        echo -e "    ${GREEN}✓ Downloaded from Grafana.com (ID: ${grafana_id})${NC}"
        download_success=$((download_success + 1))
    else
        echo -e "    ${RED}✗ Failed to download ${dashboard}${NC}"
        rm -f "${json_file}"
        download_failed=$((download_failed + 1))
    fi
done

echo ""
echo "  Download summary: ${download_success} succeeded, ${download_failed} failed"

applied_count=0
for json_file in "${DASHBOARD_DIR}"/*.json; do
    if [ -f "$json_file" ] && [ -s "$json_file" ]; then
        dashboard_name=$(basename "$json_file" .json)
        echo "  Creating ConfigMap for ${dashboard_name}..."
        if kubectl create configmap "grafana-dashboard-${dashboard_name}" \
            --namespace monitoring \
            --from-file="${dashboard_name}.json=${json_file}" \
            --dry-run=client -o yaml | \
            kubectl label --local -f - grafana_dashboard=1 -o yaml | \
            kubectl annotate --local -f - grafana_folder=Istio -o yaml | \
            kubectl apply -f -; then
            echo -e "    ${GREEN}✓ Applied${NC}"
            applied_count=$((applied_count + 1))
        else
            echo -e "    ${RED}✗ Failed to apply${NC}"
        fi
    fi
done
rm -rf "${DASHBOARD_DIR}"

if [ ${applied_count} -eq 0 ]; then
    echo -e "${RED}Warning: No Grafana dashboards were applied. Check network connectivity.${NC}"
elif [ ${applied_count} -lt 4 ]; then
    echo -e "${YELLOW}Warning: Only ${applied_count}/4 dashboards applied.${NC}"
else
    echo -e "${GREEN}All 4 Istio dashboards applied successfully.${NC}"
fi

echo -e "${YELLOW}Building and Loading demo-app Image...${NC}"
./sample-app/demo-app/build-and-load.sh

echo -e "${YELLOW}Deploying Sample Applications...${NC}"
kubectl apply -f sample-app/

echo ""
echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Port Forward Commands:"
echo "  kubectl port-forward -n observability svc/kiali 20001:20001"
echo "  kubectl port-forward -n observability svc/jaeger 16686:16686"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "Access URLs (after port-forward):"
echo "  - Kiali:      http://localhost:20001"
echo "  - Jaeger:     http://localhost:16686"
echo "  - Grafana:    http://localhost:3000 (admin/admin)"
echo "  - Prometheus: http://localhost:9090"
echo ""
echo "Test tracing:"
echo "  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl http://httpbin.istio-demo:8000/get"
echo ""
echo "Test demo-app (Redis + MongoDB + httpbin):"
echo "  kubectl exec -n istio-demo deploy/sleep -c sleep -- curl http://demo-app:8080/full-demo"
echo -e "==========================================${NC}"

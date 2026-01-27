kubectl port-forward -n observability svc/kiali 20001:20001 &                                                                                                    
kubectl port-forward -n observability svc/jaeger 16686:16686 &                                                                                                   
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &    
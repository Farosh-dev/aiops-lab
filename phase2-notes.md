# Phase 2: Monitoring with Prometheus and Grafana

**Goal:** see CPU and memory per pod in dashboards, and learn the basics of PromQL.
**In plain words:** install a health scanner (Prometheus) and a screen to watch it (Grafana).

This phase has no manifest files of its own. The stack is installed with Helm, and the only file change was adding resource requests and limits to `phase1/app.yaml`.

## What was installed

The `kube-prometheus-stack` Helm chart in its own `monitoring` namespace:

| Component | Role |
| --- | --- |
| Prometheus | Collects metrics and stores them, queried with PromQL |
| Grafana | Dashboards on top of Prometheus data |
| Alertmanager | Groups and routes alerts (used in Phase 3) |
| node-exporter | CPU, memory and disk metrics of the node |
| kube-state-metrics | Metrics about Kubernetes objects, such as pod restarts |
| prometheus-operator | Runs Prometheus and Alertmanager from Kubernetes objects |

## Steps

1. Check the cluster:
   ```bash
   cd ~/aiops-lab
   kubectl get nodes
   kubectl get pods
   ```
2. Add the Helm repository:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   ```
3. Install the stack:
   ```bash
   helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
   ```
4. Wait for the pods. The first start takes several minutes because the images are large:
   ```bash
   kubectl get pods -n monitoring -w
   ```
   If a pod stays in `ContainerCreating`, run `kubectl describe pod <name> -n monitoring` and read the Events: `Pulling` means it is still downloading.
5. Read the Grafana password from the Kubernetes Secret (it is never stored in Git), then open a tunnel:
   ```bash
   kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo
   kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
   ```
   Open `http://localhost:3000` and log in as `admin`. Keep the tunnel terminal running.
6. Open the dashboard `Kubernetes / Compute Resources / Namespace (Pods)` with the namespace set to `default`. The node dashboard is `Node Exporter / Nodes`.
7. Add resource requests and limits to the container in `phase1/app.yaml`:
   ```yaml
   resources:
     requests:
       cpu: 50m
       memory: 64Mi
     limits:
       cpu: 200m
       memory: 128Mi
   ```
   Apply it and check:
   ```bash
   kubectl apply -f phase1/app.yaml
   kubectl describe pod -l app=web | grep -A4 "Limits"
   ```
8. Send some traffic through a second tunnel and refresh the dashboard:
   ```bash
   kubectl port-forward svc/web 8080:80
   for i in $(seq 1 5000); do curl -s localhost:8080 > /dev/null; done
   ```

## Observations

- Before the requests and limits existed, the Utilisation panels showed "No data": there was nothing to compute a percentage against, and the pods were idle.
- After adding them and sending traffic, the panels showed values such as CPU 8.52% of requests and 2.13% of limits, and memory 18.3% of requests and 9.15% of limits.
- One pod took almost all the load, because `kubectl port-forward` connects to a single pod even when it targets a Service. It is a debugging tool, not a load-balancing test.

## PromQL basics

In Grafana, open Explore, choose the Prometheus data source, switch to Code mode and run:

```
up
kube_pod_container_status_restarts_total{namespace="default"}
increase(kube_pod_container_status_restarts_total{namespace="default"}[5m])
sum(rate(container_cpu_usage_seconds_total{namespace="default", pod=~"web.*"}[5m])) by (pod)
```

- `up` lists every target Prometheus scrapes; 1 means healthy.
- A restart counter only ever goes up, so alerts use `increase()` over a time window instead of the raw value (used in Phase 3).
- `rate()` gives the per-second change of a counter, here CPU seconds, averaged over 5 minutes.

## Key learnings

- Utilisation percentages need `requests` and `limits`; every production pod should define them.
- Monitoring must be installed before an incident: pods that were created and deleted earlier do not appear in the metrics.
- Tunnels from `kubectl port-forward` drop when the terminal closes; run the command again if a page stops loading.

## Common problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| `localhost:3000` refuses the connection | The tunnel terminal was closed | Run the `port-forward` command again |
| Explore shows "Failed to fetch" | The tunnel dropped while the page loaded | Restart the tunnel and hard refresh with `Ctrl+Shift+R` |
| Panels show "No data" | No requests or limits, or idle pods | Add `resources` and send traffic |
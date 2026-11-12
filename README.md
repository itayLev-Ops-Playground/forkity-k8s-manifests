# Forkity Kubernetes Manifests

This repository contains the Kubernetes manifests to deploy the **Forkity** application stack—comprising a React/Nginx frontend, a Node.js backend API, and a PostgreSQL 17 database—into the `app` namespace using local persistent storage.

## Architecture Overview

- **Namespace:** `app`
- **Frontend:** `itaylevops/forkity:frontend-V.0.35` exposed via `NodePort` on port `32052` (container port `80`).
- **Backend:** `itaylevops/forkity:backend-V.0.35` running on port `4000` (`ClusterIP`), connecting to PostgreSQL via `db-client:5432`.
- **Database:** `postgres:17-alpine` managed as a `StatefulSet` (`db`) with a headless service (`db`) and a client service (`db-client`).
- **Storage:** `2Gi` local `PersistentVolume` (`postgres-local`) bound to `/mnt/data/postgres` using a `local-storage` `StorageClass` (`WaitForFirstConsumer`).

## Repository Structure

| File | Kind | Resource Name | Description |
| :--- | :--- | :--- | :--- |
| `namspace.yaml` | `Namespace` | `app` | Isolates all Forkity workloads and services. |
| `storageclass-local.yaml` | `StorageClass` | `local-storage` | Uses `kubernetes.io/no-provisioner` with `Retain` policy. |
| `persistentvolume-local.yaml` | `PersistentVolume` | `postgres-local` | Allocates `2Gi` at `/mnt/data/postgres` on labeled storage nodes. |
| `db-statfulset.yaml` | `StatefulSet` | `db` | Runs PostgreSQL 17 with `pg_isready` probes and a `2Gi` PVC template. |
| `db-svc.yaml` | `Service` | `db`, `db-client` | Headless service for StatefulSet identity and `ClusterIP` service for backend connections. |
| `backend-deploy.yaml` | `Deployment` | `backend` | Runs the Node.js API on port `4000` with `/api/health` readiness checks. |
| `backend-svc.yaml` | `Service` | `backend` | Internal `ClusterIP` service exposing port `4000`. |
| `frontend-deploy.yaml` | `Deployment` | `frontend` | Runs the frontend container on port `80`. |
| `frontend-svc.yaml` | `Service` | `frontend` | Exposes the web UI externally via `NodePort` `32052`. |

## Prerequisites

Before applying the manifests, prepare your target Kubernetes node and database credentials:

1. **Label the Storage Node:**
   The `postgres-local` PersistentVolume uses `nodeAffinity` requiring the label `forkity.local/storage=db` (control-plane tolerations are already configured on the database pod):
   ```bash
   kubectl label nodes <target-node-name> forkity.local/storage=db
   ```

2. **Create the Host Storage Directory:**
   On the labeled node, create the local data path referenced by the `PersistentVolume`:
   ```bash
   sudo mkdir -p /mnt/data/postgres
   ```

3. **Create the Database Secret:**
   Both the `db` StatefulSet and `backend` Deployment require a secret named `forkity-db` in the `app` namespace. Create the namespace and secret first:
   ```bash
   kubectl apply -f namspace.yaml

   kubectl create secret generic forkity-db \
     --namespace app \
     --from-literal=POSTGRES_DB=forkity \
     --from-literal=POSTGRES_USER=forkity_user \
     --from-literal=POSTGRES_PASSWORD=<your-secure-password>
   ```

## Deployment Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com
   cd forkity-k8s-manifests
   ```

2. **Apply storage and database manifests:**
   ```bash
   kubectl apply -f storageclass-local.yaml
   kubectl apply -f persistentvolume-local.yaml
   kubectl apply -f db-svc.yaml
   kubectl apply -f db-statfulset.yaml
   ```

3. **Apply backend and frontend manifests:**
   ```bash
   kubectl apply -f backend-svc.yaml
   kubectl apply -f backend-deploy.yaml
   kubectl apply -f frontend-svc.yaml
   kubectl apply -f frontend-deploy.yaml
   ```

4. **Verify the deployment:**
   ```bash
   kubectl get all,pvc -n app
   ```

## Accessing the Application

Once all pods pass their readiness probes, access the frontend in your browser via any node's IP address on port `32052`:

```text
http://<NODE_IP>:32052
```

## Cleanup

To remove the application resources:
```bash
kubectl delete -f .
```
*(Note: Because `persistentVolumeReclaimPolicy` is set to `Retain`, the `postgres-local` PV and data in `/mnt/data/postgres` will remain intact until manually deleted.)*

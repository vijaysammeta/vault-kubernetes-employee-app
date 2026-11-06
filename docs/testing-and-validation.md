
# Testing and Validation

## 1. Kubernetes Cluster Validation

### Check Kubernetes Nodes

```bash
kubectl get nodes -o wide
```

Expected result:
- Control plane node is Ready.
- Worker nodes are Ready.

### Check Application Namespace

```bash
kubectl get pods -n production
```

Expected result:

| Component | Expected Status |
|---|---|
| MySQL | 2/2 Running |
| Backend | 2/2 Running per pod |
| Frontend | 1/1 Running per pod |

## 2. Vault Deployment Validation

### Check Vault Pods

```bash
kubectl get pods -n vault
```

### Check Vault Status

```bash
kubectl exec -n vault vault-0 -- vault status
```

Expected:

```text
Initialized: true
Sealed: false
```

## 3. Vault KV Secret Validation

Read the MySQL secret metadata and values from Vault CLI:

```bash
kubectl exec -n vault vault-0 -- vault kv get secret/mysql
```

Expected fields:
- username
- password

Do not publish actual credential values in screenshots or logs.

## 4. Kubernetes Authentication Validation

Check enabled authentication methods:

```bash
kubectl exec -n vault vault-0 -- vault auth list
```

Expected:
- kubernetes/
- token/

Check the Vault Kubernetes role:

```bash
kubectl exec -n vault vault-0 -- \
  vault read auth/kubernetes/role/mysql-app
```

Verify:
- ServiceAccount: mysql-app
- Namespace: production
- Policy: mysql-policy
- TTL: 1h

## 5. Vault Policy Validation

Check the policy:

```bash
kubectl exec -n vault vault-0 -- \
  vault policy read mysql-policy
```

Expected policy:

```hcl
path "secret/data/mysql" {
  capabilities = ["read"]
}
```

## 6. Vault Agent Injection Validation

Check backend pods:

```bash
kubectl get pods -n production
```

Check Vault Agent containers:

```bash
kubectl get pods -n production \
  -o custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name
```

Verify injected files without displaying their contents:

```bash
kubectl exec -n production deploy/backend -- \
  ls -l /vault/secrets/
```

Expected files:

```text
db-user
db-password
```

Check MySQL pod injection:

```bash
kubectl exec -n production mysql-0 -- \
  ls -l /vault/secrets/
```

## 7. MySQL Database Validation

Check MySQL pod:

```bash
kubectl get pod mysql-0 -n production
```

Connect using Vault-injected credentials:

```bash
kubectl exec -n production mysql-0 -c mysql -- sh -c '
MYSQL_PWD="$(cat /vault/secrets/db-password)" mysql \
-h 127.0.0.1 \
-u "$(cat /vault/secrets/db-user)" \
company -e "SELECT * FROM employees;"
'
```

Expected employee records:

```text
+----+-------+
| id | name  |
+----+-------+
|  1 | Vijay |
|  2 | Rahul |
|  3 | Priya |
+----+-------+
```

## 8. Persistent Storage Validation

Check PersistentVolumeClaims:

```bash
kubectl get pvc -n production
```

Check PersistentVolumes:

```bash
kubectl get pv
```

Expected:
- MySQL PVC is Bound.
- EBS volume is provisioned.
- Storage capacity is 10Gi.

## 9. Backend API Validation

Start port forwarding:

```bash
kubectl port-forward -n production \
  svc/backend-service 3000:80
```

Open another terminal and execute:

```bash
curl http://localhost:3000/api/employees
```

Expected response:

```json
[
  {"id": 1, "name": "Vijay"},
  {"id": 2, "name": "Rahul"},
  {"id": 3, "name": "Priya"}
]
```

This confirms:

- Backend application is running.
- Backend connects to MySQL.
- Database credentials are available through Vault Agent injection.
- Employee records are returned successfully.

## 10. Frontend API Proxy Validation

Start frontend port forwarding:

```bash
kubectl port-forward -n production \
  svc/frontend-service 8080:80
```

Test the API through NGINX:

```bash
curl http://localhost:8080/api/employees
```

Expected:
- HTTP 200 response.
- Employee JSON records.

This confirms NGINX forwards API requests to backend-service.

## 11. Ingress Validation

Check Ingress resource:

```bash
kubectl get ingress -n production
```

Check Ingress Controller:

```bash
kubectl get pods -n ingress-nginx
```

Check LoadBalancer DNS:

```bash
kubectl get svc ingress-nginx-controller \
  -n ingress-nginx
```

Open the AWS Network Load Balancer DNS name in a browser.

Expected:
- Employee dashboard loads.
- Frontend communicates with backend.
- Employee records are displayed.

## 12. Final Testing Results

| Test | Result |
|---|---|
| Kubernetes cluster | Passed |
| Vault installation | Passed |
| Vault KV v2 | Passed |
| Kubernetes authentication | Passed |
| Vault policy | Passed |
| Vault Agent injection | Passed |
| MySQL connectivity | Passed |
| Backend API | Passed |
| Frontend API proxy | Passed |
| NGINX Ingress | Passed |
| Application access through NLB | Passed |

## 13. Conclusion

The application was successfully tested end to end.

React frontend requests are routed through NGINX to the Node.js backend. The backend connects to MySQL using credentials provided through HashiCorp Vault.

Kubernetes authentication and Vault Agent Injector provide a secure mechanism for delivering database credentials to application workloads without hardcoding them in the application deployment configuration.

Note: Test results above reflect the project validation already reported. Re-run commands if you need to capture fresh evidence.

# Implementation Steps – Vault Kubernetes Employee Management Application

## 1. Project Environment

Cloud Provider: AWS
Region: ap-south-1 (Mumbai)
Kubernetes: kOps
Container Runtime: containerd
Frontend: React + NGINX
Backend: Node.js
Database: MySQL 8.0
Secret Management: HashiCorp Vault
Ingress Controller: NGINX Ingress Controller
Storage: AWS EBS

## 2. Verify Kubernetes Cluster

Check Kubernetes nodes:

```bash
kubectl get nodes -o wide
```

Check cluster information:

```bash
kubectl cluster-info
```

Check Kubernetes namespaces:

```bash
kubectl get namespaces
```

## 3. Create Application Namespace

Create the production namespace:

```bash
kubectl create namespace production
```

Verify:

```bash
kubectl get namespaces
```

## 4. Install HashiCorp Vault

Add the HashiCorp Helm repository:

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
```

Update Helm repositories:

```bash
helm repo update
```

Create the Vault namespace:

```bash
kubectl create namespace vault
```

Install Vault using Helm.

For this project, Vault was installed using chart version 0.34.1:

```bash
helm install vault hashicorp/vault \
  --namespace vault \
  --version 0.34.1
```

Verify Vault pods:

```bash
kubectl get pods -n vault
```

Check Vault status:

```bash
kubectl exec -n vault vault-0 -- vault status
```

NOTE: Vault was configured in standalone mode with file storage for this learning project.

## 5. Initialize and Unseal Vault

Initialize Vault:

```bash
kubectl exec -it -n vault vault-0 -- vault operator init
```

IMPORTANT:
- Initialization is performed only once.
- Save the unseal keys securely.
- Save the initial root token securely.
- Never upload these credentials to GitHub.

Unseal Vault using three of the five generated unseal keys:

```bash
kubectl exec -it -n vault vault-0 -- vault operator unseal
```

Repeat the command with the required three different keys.

Verify:

```bash
kubectl exec -n vault vault-0 -- vault status
```

Expected status:

```text
Initialized: true
Sealed: false
```

## 6. Configure Vault KV Version 2

Open a shell inside the Vault pod:

```bash
kubectl exec -it -n vault vault-0 -- sh
```

Authenticate using the securely saved root token:

```bash
vault login
```

Enable the KV version 2 secrets engine if it is not already enabled at secret/:

```bash
vault secrets enable -path=secret kv-v2
```

Store MySQL credentials:

```bash
vault kv put secret/mysql \
  username=<MYSQL_USERNAME> \
  password=<MYSQL_PASSWORD>
```

Replace the placeholders with the actual database credentials.

Verify the secret:

```bash
vault kv get secret/mysql
```

Do not include actual credentials in GitHub documentation or screenshots.

## 7. Create Vault Policy

Create the policy file:

```bash
vi mysql-policy.hcl
```

Add:

```hcl
path "secret/data/mysql" {
  capabilities = ["read"]
}
```

Load the policy into Vault:

```bash
vault policy write mysql-policy mysql-policy.hcl
```

Verify:

```bash
vault policy read mysql-policy
```

## 8. Enable Kubernetes Authentication

Enable Kubernetes authentication:

```bash
vault auth enable kubernetes
```

Configure Kubernetes authentication from inside the Vault pod:

```bash
vault write auth/kubernetes/config \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

Grant the Vault ServiceAccount permission to review Kubernetes tokens.

Run from the Kops management server:

```bash
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault:vault
```

## 9. Create Kubernetes ServiceAccount

Create the application ServiceAccount:

```bash
kubectl create serviceaccount mysql-app -n production
```

Verify:

```bash
kubectl get serviceaccount -n production
```

## 10. Create Vault Kubernetes Role

Run inside the Vault CLI:

```bash
vault write auth/kubernetes/role/mysql-app \
  bound_service_account_names=mysql-app \
  bound_service_account_namespaces=production \
  policies=mysql-policy \
  ttl=1h
```

Verify:

```bash
vault read auth/kubernetes/role/mysql-app
```

This connects the production namespace ServiceAccount to the mysql-policy.

## 11. Configure MySQL Root Password

Run on the Kops management server:

```bash
kubectl create secret generic mysql-root \
  --namespace production \
  --from-literal=MYSQL_ROOT_PASSWORD="$(openssl rand -hex 24)"
```

This creates the Kubernetes Secret used for the MySQL root password.

The secret is separate from the application database credentials stored in Vault.

Do not recreate it if it already exists.

## 12. Deploy MySQL StatefulSet

Apply the MySQL manifest:

```bash
kubectl apply -f kubernetes/mysql-deployment.yaml
```

Verify StatefulSet:

```bash
kubectl get statefulsets -n production
```

Verify MySQL pod:

```bash
kubectl get pods -n production
```

Verify persistent volume claims:

```bash
kubectl get pvc -n production
```

The MySQL StatefulSet uses:
- MySQL 8.0
- One replica
- 10Gi AWS EBS persistent storage
- Vault Agent Injector
- Vault-injected database username and password

## 13. Create MySQL Database and Employee Table

Connect to the MySQL pod:

```bash
kubectl exec -it -n production mysql-0 -c mysql -- bash
```

The database credentials are injected by Vault Agent.

Create the employee table using the Vault-injected credentials:

```bash
MYSQL_PWD="$(cat /vault/secrets/db-password)" mysql \
-h 127.0.0.1 \
-u "$(cat /vault/secrets/db-user)" \
company
```

Execute:

```sql
CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

INSERT INTO employees (name)
VALUES ('Vijay'), ('Rahul'), ('Priya');

SELECT * FROM employees;
```

Exit MySQL:

```sql
exit
```

## 14. Deploy Backend Application

Apply the backend Deployment and Service:

```bash
kubectl apply -f kubernetes/backend-deployment.yaml
```

The backend uses:

```text
Docker Image: vijaysammeta/backend:v4
Replicas: 2
Container Port: 3000
Service: backend-service
Service Port: 80
```

The backend retrieves its database credentials from Vault Agent injected files.

Check backend pods:

```bash
kubectl get pods -n production
```

Check backend Service:

```bash
kubectl get svc -n production
```

## 15. Configure Frontend NGINX

Apply the frontend NGINX ConfigMap:

```bash
kubectl apply -f kubernetes/frontend-nginx.yaml
```

The NGINX configuration forwards API requests to:

```text
http://backend-service
```

API path:

```text
/api/
```

The frontend communicates with the backend through Kubernetes internal networking.

## 16. Deploy React Frontend

Apply the frontend Deployment and Service:

```bash
kubectl apply -f kubernetes/frontend-deployment.yaml
```

The frontend uses:

```text
Docker Image: vijaysammeta/frontend:v2
Replicas: 2
Container Port: 80
Service: frontend-service
```

Verify frontend pods:

```bash
kubectl get pods -n production
```

## 17. Install NGINX Ingress Controller

Add the NGINX Ingress Helm repository:

```bash
helm repo add ingress-nginx \
  https://kubernetes.github.io/ingress-nginx
```

Update Helm:

```bash
helm repo update
```

Install the controller:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

Verify controller:

```bash
kubectl get pods -n ingress-nginx
```

Check LoadBalancer Service:

```bash
kubectl get svc -n ingress-nginx
```

AWS provisions a Network Load Balancer for the NGINX Ingress Service.

## 18. Configure Application Ingress

Apply the Ingress resource:

```bash
kubectl apply -f kubernetes/app-ingress.yaml
```

Verify:

```bash
kubectl get ingress -n production
```

Get the NLB DNS name:

```bash
kubectl get svc ingress-nginx-controller \
  -n ingress-nginx
```

Access the application using the NLB DNS name:

```text
http://<NLB-DNS-NAME>
```

The Ingress routes incoming requests to frontend-service.

## 19. Verify Complete Application

Check all application resources:

```bash
kubectl get all -n production
```

Check Vault resources:

```bash
kubectl get pods -n vault
```

Check the employee API:

```bash
kubectl port-forward -n production \
  svc/backend-service 3000:80
```

In another terminal:

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

Open the NLB DNS name in a browser to access the React employee dashboard.

## 20. Final Implementation Result

Successfully implemented:

1. AWS Kubernetes cluster using kOps.
2. HashiCorp Vault installation using Helm.
3. KV version 2 secrets engine.
4. Kubernetes authentication.
5. Vault policies and Kubernetes roles.
6. Vault Agent Injector integration.
7. MySQL StatefulSet with AWS EBS storage.
8. Node.js backend deployment with two replicas.
9. React frontend deployment with two replicas.
10. NGINX reverse proxy for backend API requests.
11. NGINX Ingress Controller with AWS Network Load Balancer.
12. End-to-end employee application connectivity.

The application successfully retrieves employee records from MySQL while using Vault to provide database credentials to the backend and MySQL workloads.

## Important Notes

- Vault is deployed in standalone file-storage mode for this learning project.
- Route 53 is not configured in the current deployment.
- The application currently uses the AWS NLB DNS name directly.
- HTTPS, Vault auto-unseal, HA and automatic database credential rotation are future production-hardening tasks.
- Never commit Vault root tokens, unseal keys or database passwords.

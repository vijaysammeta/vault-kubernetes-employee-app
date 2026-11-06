# Vault Kubernetes Authentication and Role Setup

## 1. Enable Kubernetes Authentication

Vault uses Kubernetes authentication to verify application pods.

```bash
vault auth enable kubernetes
```

## 2. Configure Kubernetes Authentication

Configure Vault to communicate with the Kubernetes API server.

```bash
vault write auth/kubernetes/config \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

## 3. Create Kubernetes ServiceAccount

Create the application ServiceAccount in the production namespace.

```bash
kubectl create serviceaccount mysql-app -n production
```

## 4. Configure Vault Token Review Permissions

Allow the Vault ServiceAccount to review Kubernetes service account tokens.

```bash
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault:vault
```

## 5. Create Vault Policy

Create the policy file named mysql-policy.hcl.

```hcl
path "secret/data/mysql" {
  capabilities = ["read"]
}
```

Upload the policy to Vault.

```bash
vault policy write mysql-policy mysql-policy.hcl
```

## 6. Create Vault Kubernetes Role

Bind the Kubernetes ServiceAccount to the Vault policy.

```bash
vault write auth/kubernetes/role/mysql-app \
  bound_service_account_names=mysql-app \
  bound_service_account_namespaces=production \
  policies=mysql-policy \
  ttl=1h
```

## 7. Store MySQL Credentials in Vault

The database username and password are stored in the KV v2 secrets engine.

```bash
vault kv put secret/mysql \
  username=<MYSQL_USERNAME> \
  password=<MYSQL_PASSWORD>
```

Replace the placeholders with your actual credentials when running the command. Never commit real credentials to GitHub.

## 8. Verify Vault Role

```bash
vault read auth/kubernetes/role/mysql-app
```

## 9. Verify Vault Policy

```bash
vault policy read mysql-policy
```

## 10. Verify Stored Secret

```bash
vault kv get secret/mysql
```

Do not expose the secret values in screenshots or logs.

## Authentication Flow

1. The application pod uses the mysql-app ServiceAccount.
2. Vault Agent authenticates with Vault using Kubernetes authentication.
3. Vault validates the Kubernetes ServiceAccount token.
4. Vault assigns the mysql-policy to the authenticated application.
5. Vault Agent retrieves the MySQL credentials from the KV v2 secrets engine.
6. Vault Agent writes the credentials into files under /vault/secrets/.
7. The backend and MySQL containers use the injected credentials.

## Security

- Avoid hardcoding database passwords in Kubernetes manifests.
- Use Vault policies with minimum required permissions.
- Do not commit root tokens or unseal keys.
- Use separate ServiceAccounts and policies for different applications.

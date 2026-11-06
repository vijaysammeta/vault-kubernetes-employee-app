# Security Configuration

## 1. Security Architecture

This project uses HashiCorp Vault to manage sensitive database credentials and Kubernetes authentication to authorize application workloads.

Security components:

- HashiCorp Vault
- Kubernetes Authentication
- Vault Agent Injector
- Vault ACL Policy
- Kubernetes ServiceAccount
- Kubernetes Secrets
- AWS EBS Persistent Storage
- Kubernetes Namespace Isolation

## 2. Secure Database Credentials

MySQL application credentials are stored in Vault KV version 2.

Secret path:

```text
secret/mysql
```

Secret fields:

```text
username
password
```

The backend and MySQL workloads retrieve credentials from Vault through Vault Agent Injector.

Database passwords are not hardcoded in the backend application deployment.

## 3. Kubernetes Authentication

Vault uses Kubernetes authentication to verify application workloads.

Authentication method:

```text
auth/kubernetes
```

Application ServiceAccount:

```text
mysql-app
```

Kubernetes namespace:

```text
production
```

Vault validates the Kubernetes ServiceAccount token before issuing a Vault token.

## 4. Vault Role Configuration

Vault role:

```text
mysql-app
```

Role configuration:

| Parameter | Value |
|---|---|
| Authentication | Kubernetes |
| ServiceAccount | mysql-app |
| Namespace | production |
| Policy | mysql-policy |
| Token TTL | 1 hour |

This role allows the authorized Kubernetes workload to access the MySQL secret.

## 5. Vault ACL Policy

Policy name:

```text
mysql-policy
```

Policy configuration:

```hcl
path "secret/data/mysql" {
  capabilities = ["read"]
}
```

The policy follows the principle of least privilege.

The application receives read access to the MySQL secret rather than administrative access to Vault.

## 6. Vault Agent Injector

Vault Agent Injector automatically injects a Vault Agent sidecar into annotated Kubernetes pods.

Annotations used:

```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "mysql-app"
```

Injected secret files:

```text
/vault/secrets/db-user
/vault/secrets/db-password
```

The application startup process reads the injected files and configures database connection variables.

This avoids placing application database passwords directly inside Kubernetes Deployment YAML files.

## 7. Kubernetes Secret Protection

The MySQL root password is stored separately in a Kubernetes Secret.

Secret name:

```text
mysql-root
```

Namespace:

```text
production
```

It is referenced by the MySQL StatefulSet through secretKeyRef.

The MySQL root password is not stored in the GitHub repository.

## 8. Namespace Isolation

Application resources are deployed in:

```text
production
```

Vault resources are deployed in:

```text
vault
```

This provides logical separation between application workloads and the Vault service.

## 9. Persistent Storage Security

MySQL uses AWS EBS persistent storage through a Kubernetes PersistentVolumeClaim.

Configuration:

```text
Storage: 10Gi
Access Mode: ReadWriteOnce
StorageClass: kops-csi-1-21
```

Persistent storage allows database data to survive MySQL pod replacement.

Note: EBS persistence alone does not provide a backup or disaster recovery strategy.

## 10. Security Best Practices

The following practices should be followed:

- Never hardcode database passwords in application source code.
- Never upload Vault root tokens to GitHub.
- Never upload Vault unseal keys to GitHub.
- Never commit Kubernetes Secret values.
- Use Vault policies with minimum required permissions.
- Use separate ServiceAccounts for different applications where possible.
- Restrict access to Vault UI and API.
- Use HTTPS and TLS for production access.
- Enable Vault audit logging.
- Configure regular Vault backups.
- Rotate database credentials using a tested rotation procedure.
- Restrict network communication using Kubernetes NetworkPolicies.

## 11. Current Project Security Limitations

This project is designed for learning and demonstration.

Current configuration:

| Feature | Status |
|---|---|
| Vault KV v2 | Implemented |
| Kubernetes authentication | Implemented |
| Vault ACL policy | Implemented |
| Vault Agent Injector | Implemented |
| Database credential injection | Implemented |
| Vault HA | Not configured |
| AWS KMS auto-unseal | Not configured |
| HTTPS/TLS | Not configured |
| Automatic DB password rotation | Not configured |
| NetworkPolicies | Not configured |
| Vault audit logging | Not configured |

## 12. Conclusion

HashiCorp Vault is integrated with Kubernetes to securely manage and inject MySQL database credentials into application workloads.

Kubernetes authentication verifies workloads, Vault roles assign policies, and Vault Agent Injector delivers credentials to the required containers.

This reduces hardcoded credential exposure and provides centralized secret management for the employee management application.

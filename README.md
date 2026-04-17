# WentToProd — DevOps na AWS: CI/CD, IaC i Monitoring

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=Prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)

> Projekt pokazuje pełny cykl życia aplikacji — 
> od Commita do działającej aplikacji na AWS. 
> Każdy push na main przez pipeline: 
> budowanie obrazu, skanowanie bezpieczeństwa, provisioning infrastruktury i zero-downtime deployment. 
> Historia każdego deployu trafia do bazy danych i jest widoczna na stronie.

---

## Architektura i Zarządzanie kosztami 

![Diagram Architektury AWS](./docs/infra.png)

Infrastruktura jest podzielona na **3 workspaces Terraform HCP**, 
co pozwala niszczyć kosztowne zasoby i pozostawiać te które nie generują kosztów skracając czas działania pipeline.

| Workspace   | Zawartość                                                     | Kiedy działa? |
|-------------|---------------------------------------------------------------|---------------|
| **network** | VPC, Subnety, Internet Gateway, Security Groups, Route53, ACM | Zawsze        |
| **db**      | RDS PostgreSQL Multi-AZ                                       | Zawsze        |
| **infra**   | ALB, ASG, EC2, NAT Gateway, WAF, Monitoring                   | Na żądanie    |

Infrastruktura z workspace `infra` jest **automatycznie niszczona codziennie o 22:30 UTC** - Workspace `network` oraz `db` pozostają.
Takie rozwiązanie pozwala zminimalizować koszty jednocześnie zapewniając szybsze wdrożenie aplikacji usuwając potrzebę tworzenia infrastruktury która nie generuje kosztów.

---

## Stack technologiczny

| Kategoria      | Technologie                                                           |
|----------------|-----------------------------------------------------------------------|
| Chmura         | AWS: VPC, EC2, ALB, ASG, RDS, NAT Gateway, SSM, ACM, Route53, WAF, S3 |
| IaC            | Terraform + HCP Terraform Cloud (3 workspace'y)                       |
| CI/CD          | GitHub Actions — multi-stage pipeline z manual approvals              |
| Konteneryzacja | Docker (multi-stage build) + GitHub Container Registry                |
| Bezpieczeństwo | AWS WAF, tfsec, Trivy, SSM SecureString                               |
| Monitoring     | Prometheus + Grafana + Alertmanager                                   |

---

## Jak działa pipeline

Każdy push do `main` zmieniający pliki w `/src` uruchamia automatycznie:

TUTAJ DIAGRAM DODAC

**Szczegółowo:**
1. **Build & Push Image** — obraz Dockera jest budowany -> Skanowanie obrazu używając Triva -> Push obrazu z tagiem SHA commita i `latest` do GHCR.
2. **Terraform - Security Scan** — Sprawdzanie infrastruktury Terraforma pod kątem bezpieczeństwa.
3. **Terraform Plan** — dla każdej warstwy wykonywany jest plan.
4. **Terraform Apply** — Jeżeli Terraform Plan zwróciło brak zmian, pomijamy ten krok. Gdy są zmiany oczekujemy na zatwierdzenie przez GitHub Environments -> Terraform Apply
5. **Register Commit into DB** — POST na `/deploys` rejestruje SHA, autora i czas w PostgreSQL
7. **Instance Refresh** — ASG płynnie wymienia instancje na nowe z najnowszym obrazem (`MinHealthyPercentage=50`), zero downtime.

Każdy błąd na dowolnym etapie → powiadomienie na Slack.

---

## Bezpieczeństwo

- **AWS WAF** podpięty pod ALB — blokuje OWASP Top 10 (SQL injection, XSS, path traversal) przez AWS Managed Rules + rate limiting 1000 req/5min
- **TLS wszędzie** — certyfikat wildcard z ACM, HTTP automatycznie przekierowywany na HTTPS
- **IMDSv2** wymuszone na wszystkich EC2 (`http_tokens = required`)
- **Szyfrowanie** — RDS encrypted, S3 SSE-AES256, SSM SecureString z KMS
- **Least privilege IAM** — osobne role dla EC2 aplikacyjnych i monitoringu, każda z uprawnieniami tylko do potrzebnych zasobów
- **Izolacja sieciowa** — EC2 i RDS w prywatnych podsieciach, dostęp z internetu tylko przez ALB
- **RDS Multi-AZ** — synchroniczna replika, automatyczny failover, backup 7 dni

---

## Monitoring i alerty

Dedykowana instancja monitoringu w prywatnej podsieci uruchamia Prometheus, Grafana i Alertmanager jako kontenery używając Docker Compose.

- **Node Exporter** na każdej instancji ASG zbiera metryki systemowe (CPU, RAM, dysk, sieć)
- **Prometheus** używa EC2 Service Discovery — automatycznie wykrywa instancje po tagu aby Instancje które zostały wymienione przez ASG również były widoczne
- **Grafana** prezentuje metryki na preinstalowanym dashboardzie Node Exporter
- **Alertmanager** wysyła powiadomienia na Slack gdy:
  - instancja przestaje odpowiadać (`InstanceDown` — po 1 minucie)
  - CPU przekracza 80% przez 5 minut (`HighCPU`)
  - wolne miejsce na dysku spada poniżej 20% (`HighDisk`)

**Dostęp do Grafany** (przez SSM port forwarding, bez otwierania portów publicznych):
```bash
./scripts/grafana-forward.sh
# Grafana dostępna pod http://localhost:3000
```

---

## Zarządzanie kosztami

| Zasób                                                  | Koszt/mies (przybliżony) |
|--------------------------------------------------------|--------------------------|
| RDS Multi-AZ (db.t3.micro)                             | ~$30                     |
| NAT Gateway × 2                                        | ~$64                     |
| EC2 × 3 (t3.micro)                                     | ~$25                     |
| ALB                                                    | ~$16                     |
| S3, Route53, misc                                      | ~$5                      |
| **Łącznie gdy infra działa**                           | **~$140**                |
| **Łącznie gdy infra zniszczona** (tylko RDS + network) | **~$35**                 |

Warstwa `infra` niszczona codziennie o 22:30 UTC redukuje koszty o ~75%.

---

## Uruchomienie od zera

### Wymagania
- AWS CLI z dostępem do konta (`aws configure`)
- Terraform CLI
- Konto HCP Terraform z 3 workspace'ami: `wenttoprod-network`, `wenttoprod-db`, `wenttoprod-infra`

### 1. Sekrety w GitHub Actions

W ustawieniach repozytorium → Settings → Secrets dodaj:

| Secret             | Opis                                    |
|--------------------|-----------------------------------------|
| `AWS_KEY`          | AWS Access Key ID                       |
| `AWS_SECRET`       | AWS Secret Access Key                   |
| `AWS_REGION`       | Region (np. `eu-central-1`)             |
| `TF_API_TOKEN`     | Token HCP Terraform                     |
| `SLACK_BOT_TOKEN`  | Token bota Slack                        |
| `SLACK_CHANNEL_ID` | ID kanału Slack do powiadomień pipeline |

W Settings → Variables dodaj:

| Variable     | Opis                           |
|--------------|--------------------------------|
| `TF_VERSION` | Wersja Terraform (np. `1.9.0`) |

### 2. Parametry w SSM Parameter Store

Uruchom skrypt bootstrap — tworzy wszystkie wymagane parametry jako SecureString:

```bash
./scripts/bootstrap-ssm.sh <ghcr-login> <ghcr-password> <api-key> <slack-incoming-webhook-url>
```

Terraform automatycznie doda `/prod/db-connection-string` przy pierwszym `apply` na workspace `db`.

### 3. Wdrożenie infrastruktury

```bash
# Warstwa sieciowa — jednorazowo
cd terraform/network && terraform init && terraform apply

# Baza danych — jednorazowo
cd terraform/db && terraform init && terraform apply

# Infrastruktura aplikacyjna
cd terraform/infra && terraform init && terraform apply
```

Lub push na `main` ze zmianami w `/src` — pipeline zrobi to automatycznie.
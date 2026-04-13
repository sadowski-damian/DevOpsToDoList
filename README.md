# WentToProd - Praktyczny projekt DevOps: CI/CD, IaC i Monitoring na AWS

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=Prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)

> **WentToProd** to projekt DevOps demonstrujący pełny cykl życia oprogramowania - od Commita do działającej aplikacji na AWS. Projekt kładzie nacisk na bezpieczeństwo, optymalizację kosztów i automatyzację całego procesu wdrożenia.

---

## Spis Treści
1. [Architektura i zarządzanie kosztami](#architektura-i-zarządzanie-kosztami)
2. [Kluczowe Funkcjonalności](#kluczowe-funkcjonalności)
3. [Stack Technologiczny](#stack-technologiczny)
4. [Proces CI/CD](#proces-cicd)
5. [Monitoring i Observability](#monitoring-i-observability)
6. [Instrukcja Uruchomienia](#instrukcja-uruchomienia)

---

## Architektura i zarządzanie kosztami

![Diagram Architektury AWS](./docs/infra.png)

Infrastruktura została zaprojektowana z myślą o optymalizacji kosztów. Terraform podzielony jest na 3 workspace używające Terraform HCP, co pozwala wyłączać najdroższe zasoby (NAT Gateway, ALB, EC2) gdy aplikacja nie jest używana - bez niszczenia danych ani konfiguracji sieci.

| Workspace   | Kiedy uruchamiany?     | Co w nim jest?                                      |
|-------------|------------------------|-----------------------------------------------------|
| **network** | Zawsze uruchomiony     | VPC, Subnets, Internet Gateway, Security Groups     |
| **db**      | Zawsze uruchomiony     | RDS PostgreSQL - przechowuje historię deployów      |
| **infra**   | Uruchamiany na żądanie | ALB, ASG, EC2 (aplikacja + monitoring), NAT Gateway |

Warstwę infra można zniszczyć jednym poleceniem **terraform destroy** lub używając pipeline poprzez workflow_dispatch **destroy.yaml** w GitHub Actions redukując koszty do minimum, a następnie postawić ponownie w kilka minut. Dane w bazie oraz wszystkie potrzebne zasoby sieciowe pozostają nienaruszone ponieważ tylko **Infra** jest niszczona.

---

## Kluczowe Funkcjonalności

* **Bezpieczneństwo:** Instancje (EC2) z aplikacją oraz jedna służąca do monitoringu wraz z bazą danych (RDS) są odizolowane w prywatnych podsieciach bez publicznych adresów IP. Cały ruch z internetu przechodzi wyłącznie przez Application Load Balancer.

* **Automatyczne skalowanie i Naprawa:** ASG utrzymuje 2 działające instancje (min. 1, desired. 2, max. 4). Gdy ALB Health Check wykryje awarię, automatycznie zastępuje instancję nową - skrypt **userDataAppEC2.sh** pobiera wtedy obraz z GHCR, odczytuje sekrety z SSM Parameter Store i uruchamia aplikację.

* **Zarządzanie Sekretami:** Żadne hasła ani tokeny nie są przechowywane w kodzie ani zmiennych środowiskowych pipeline. Credentials do bazy danych, GHCR i klucz API są przechowywane w AWS SSM Parameter Store jako SecureString (szyfrowane KMS) i pobierane przez instancje EC2.

* **IaC podzielony na 3 workspace:** Terraform podzielony jest na 3 workspace (network → db → infra), oprócz benefitów związanych z kosztami pozwala nam to zapewnić, że zmiana w warstwie compute nie może przypadkowo zmodyfikować sieci ani bazy danych.

* **Ciągłość działania:** Jeśli warstwa **infra** nie była niszczona, pipeline triggeruje **aws autoscaling start-instance-refresh** co sprawia że ASG płynnie wymienia stare instancje na nowe z najnowszym obrazem Dockera, zachowując ciągłość działania aplikacji.

* **Automatyczna Rejestracja Wdrożeń:** Po każdym udanym deployu pipeline wysyła POST na endpoint **/deploys** aplikacji (przez ALB DNS), rejestrując SHA commita, autora i czas w bazie PostgreSQL. Request zabezpieczony kluczem API z SSM.

---

## Stack Technologiczny

| Kategoria          | Technologia                                                                |
|--------------------|----------------------------------------------------------------------------| 
| **Chmura**         | AWS - VPC, EC2, ALB, ASG, RDS PostgreSQL, NAT Gateway, SSM Parameter Store |
| **IaC**            | Terraform + HCP Terraform Cloud (3 workspace'y)                            |
| **CI/CD**          | GitHub Actions - multi-stage pipeline, manual approvals, instance refresh  |
| **Konteneryzacja** | Docker (multi-stage build), GitHub Container Registry (GHCR)               |
| **Monitoring**     | Prometheus (EC2 Service Discovery), Node Exporter, Grafana                 |
| **Skrypty**        | Bash (User Data scripts, bootstrap SSM, port forwarding)                   |
| **Aplikacja**      | C# / .NET 8 + PostgreSQL (Npgsql)                                          |

---

## Proces CI/CD

Pipeline w GitHub Actions uruchamia się automatycznie przy każdym pushu na brancha **main** jeżeli powstały zmiany w kodzie aplikacji **/src**. Można go też uruchomić ręcznie przez **workflow_dispatch**.

**Etapy pipeline'u:**

1. **Build & Push** - Obraz Dockera jest budowany i publikowany do GHCR z tagiem SHA commita oraz **latest**.

2. **Terraform Plan** - Dla każdej warstwy (**network** → **db** → **infra**) wykonywany jest **terraform plan**. Każda warstwa działa niezależnie - jeśli nie ma zmian, jej joby są automatycznie pomijane.

3. **Manual Approval** - Jeśli **terraform plan** wykryje zmiany w danej warstwie, pipeline tworzy GitHub Issue i czeka na ręczne zatwierdzenie przed wykonaniem **apply**. Brak zmian = brak approval = brak apply.

4. **Terraform Apply** - Wykonywany tylko po zatwierdzeniu. Aplikuje dokładnie ten plan który był wcześniej zatwierdzony.

5. **Uruchomienie aplikacji** - Zależy od tego co się zmieniło:
    - **Infra była niszczona i tworzona od nowa** → pipeline czeka aż ALB health check zwróci 200 (nowe instancje potrzebują czasu na start)
    - **Tylko kod aplikacji się zmienił** → pipeline triggeruje **instance refresh** - ASG płynnie wymienia instancje na nowe z najnowszym obrazem, zero downtime
    - **Żadna warstwa nie miała zmian** → ten etap jest pomijany

6. **Register Deploy** - Pipeline wysyła POST na **/deploys** z danymi commita (SHA, autor, wiadomość, czas). Klucz API pobierany z SSM.

---

## Monitoring i Observability

Instancja monitoringu (EC2 w prywatnej podsieci) uruchamia Prometheus i Grafana jako kontenery Docker.

* **Node Exporter** - uruchomiony na każdej instancji EC2 w ASG, zbiera metryki systemu operacyjnego (CPU, RAM, disk, network) i udostępnia je na porcie **9100**.

* **Prometheus** - używa EC2 Service Discovery. Zamiast hardkodować adresy IP (które zmieniają się przy każdym instance refresh), automatycznie wykrywa instancje ASG po tagu **EC2-app-instance-ASG** i odpytuje je co 30 sekund.

* **Grafana** - prezentuje metryki z Node Exporter na preinstalowanym dashboardzie. Datasource Prometheus skonfigurowany automatycznie przez provisioning.

**Dostęp do Grafany**:
```bash
./scripts/grafana-forward.sh
# Grafana dostępna pod http://localhost:3000
```
---

### Niszczenie infrastruktury

Warstwa **infra** jest niszczona automatycznie codziennie o **22:30 UTC** przez **destroy.yaml**. Można też uruchomić ręcznie przez **workflow_dispatch**.

Warstwy **network** i **db** pozostają.
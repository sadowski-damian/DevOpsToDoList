# DevOpsToDoList
## Ponizszy diagram przedstawia  archietkrure aplikacji DevOpsToDOList wdrozonej na AWS
![Diagram infrastruktury AWS](docs/infra.png)

### Glowne komponenty:
- **VPC** z dwoma AZs dla wysokiej dostepnosci
- **ALB** rozdzielajacy ruch miedzy instancje EC2
- **Auto Scaling Group** z instancjami EC2 uruchamiajacymi obraz Dockera z aplikacja
- **RDS** baza danych rozpięta na dwa AZ uzywajac subnet groups
- **NAT Gateway** dostęp do internetu z prywatnych podsieci
- **Prometheus** dedykowana instancja EC2 do monitoringu w jednym AZ


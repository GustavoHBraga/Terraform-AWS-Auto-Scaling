module "aws-prod" {
  source = "../../infra"
  instancia = "t2.micro"
  regiao_aws = "us-east-1"
  chave = "IaC-Prod"
  grupoDeSeguranca = "Producao"
  minimo = 2
  maximo = 10
  nomeGrupo = "Prod"
  producao = true
}

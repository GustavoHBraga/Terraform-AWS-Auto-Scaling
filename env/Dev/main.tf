module "aws-dev" {
  source = "../../infra"
  instancia = "t2.micro"
  regiao_aws = "us-east-1"
  chave = "IaC-DEV"
  grupoDeSeguranca = "DEV"
  minimo = 1
  maximo = 1
  nomeGrupo = "DEV"
  producao = false
}

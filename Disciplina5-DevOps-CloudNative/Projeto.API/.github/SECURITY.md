# Politica de Seguranca

## Reportando uma vulnerabilidade

Nao reporte suspeitas de vulnerabilidades de seguranca em issues publicas do GitHub.

Use o canal privado de reporte de vulnerabilidades do repositorio, quando disponivel, ou entre em contato diretamente com o proprietario pelo GitHub. Inclua:

- Uma descricao da vulnerabilidade e de seu impacto potencial.
- Passos para reproduzi-la, incluindo o endpoint ou componente afetado.
- Uma prova de conceito apenas quando nao expuser dados reais de usuarios, credenciais ou recursos de producao.
- Sugestoes de correcao ou mitigacao, se houver.

Aguarde a analise do reporte antes de compartilhar detalhes publicamente.

## Escopo

Os reportes se aplicam ao codigo-fonte da aplicacao, configuracao de containers, workflows de CI/CD e configuracao documentada de deploy no Azure deste repositorio.

Nunca inclua senhas, client secrets, tokens de acesso, connection strings ou dados pessoais em issue, pull request, log ou prova de conceito.

## Versoes suportadas

As correcoes de seguranca sao aplicadas ao branch `main` atual. Atualize para a versao mais recente antes de reportar um problema que talvez ja tenha sido corrigido.

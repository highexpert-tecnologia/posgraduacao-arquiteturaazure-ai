---
name: Open Pull Request Handler
on:
  pull_request:
    types: [opened]
permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write #https://github.blog/changelog/2026-06-11-agentic-workflows-no-longer-need-a-personal-access-token/

# Tools - GitHub API access via toolsets (context, repos, issues, pull_requests)
tools:
  github:
    toolsets: [default]

# Network access
network: defaults

# Outputs - what APIs and tools can the AI use?
safe-outputs:
  create-issue:          # Creates issues (default max: 1)
    max: 5               # Optional: specify maximum number
  mentions:             # Mentions users in comments or issues
    max: 5               # Optional: specify maximum number
  add-comment:          # Adds comments to issues or PRs
    max: 5               # Optional: specify maximum number
  add-labels:           # Adds labels to issues or PRs
    max: 5               # Optional: specify maximum number
  assign-to-user:
---

# pull-request-opened

Faça ao code review do pull request aberto, fornecendo feedback e sugestões de melhorias. Analise o código, identifique problemas potenciais, e sugira alterações ou melhorias. Certifique-se de que o código segue as melhores práticas e padrões do projeto.
Esse projeto é um exemplo de DevSecOps, com foco em segurança, qualidade e automação. O código deve ser revisado com atenção especial para vulnerabilidades de segurança, práticas de codificação segura, e conformidade com as políticas do projeto, pois será estudado por uma turma de pos-graduação em DevSecOps.

## Instructions

Forneça um feedback detalhado sobre o pull request, incluindo:
- Pontos fortes do código.
- Áreas que podem ser melhoradas.
- Sugestões de refatoração ou otimização.

Ao final, escreva um poema sobre a vida de um estudante de pos graduação em DevSecOps, destacando os desafios, aprendizados e a jornada de crescimento pessoal e profissional.

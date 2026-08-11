Obrigado por contribuir com o Gem-Cli!

Como manter este repositório:

- Use a raiz (ex.: `latest.json`, `1.0.0.json`) para metadados consumíveis por scripts e instaladores.
- Para cada release, gere o binário e crie uma Release no GitHub anexando os binários.
- Atualize `1.0.0.json` com os metadados e `latest.json` apontando à versão atual.

Guidelines de Pull Request
- Faça forks e abra PRs para melhorias de documentação e scripts.
- Marque o tipo de mudança no título: [feature], [fix], [docs], [chore].

Como mudar a localização dos arquivos de versões
- Se preferir manter os JSONs em `versions/`, mova os arquivos e atualize `bin/install.sh` para apontar ao novo caminho RAW (por exemplo `https://raw.githubusercontent.com/HintyCloud/Gem-Cli/main/versions/latest.json`).

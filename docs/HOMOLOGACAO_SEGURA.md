# Homologação segura — Card 37

Estado: **preparado para implantação; validação externa pendente**.
O laboratório local valida TLS/proxy com uma CA temporária. Ele não comprova
certificado público, entrega SMTP, persistência do provedor ou restauração real
do PostgreSQL. Ver resultados em `EVIDENCIAS_SEGURANCA.md`.

## Dependências e configuração

Aplicação: Python 3.12, Django 5.2.18, DRF 3.16.1, Djoser 2.3.5,
django-cors-headers 4.9.0, psycopg2-binary 2.9.10; Flutter 3.47.4/Dart 3.13.3
mantidos conforme `.fvmrc`/CI. Gunicorn 26.2.2 está fixado no arquivo de
requirements por arquivo-fonte oficial, commit e SHA-256, pois o índice
consultado ainda não oferecia essa versão. A instalação usa pip, sem executar Git.
Se um mirror não disponibilizar o arquivo, disponibilize o mesmo arquivo
verificado internamente; não substitua a versão silenciosamente.

Instalar `backend/requirements-geographic.txt` para Redis e
`backend/requirements-catalog.txt` para ferramentas de catálogo. `pip check`
integra o gate. Não reduzir a cobertura mínima de 80%.

Configuração local continua em `.env`. Homologação usa módulo explícito
`acessoja.settings_staging`, sem ler o `.env` do desenvolvedor. DEBUG deve ser
False. Falta de segredo forte, PostgreSQL, Redis compartilhado, origem HTTPS,
hosts, proxy, contato e diretórios privados impede inicialização.

Copie `.env.staging.example` para `/etc/acessoja/staging.env` **fora do checkout**;
substitua todos os placeholders. Permissão Linux 0600, diretórios 0700; Windows
deve usar ACL só da conta operadora. O arquivo contém `STAGING_ENV_FILE` apontando
para si, `BACKUP_ROOT` absoluto e senhas distintas para app e administrador.
Caracteres reservados da senha devem ser codificados na DATABASE_URL. Nunca
cole a URL completa, segredos SMTP ou arquivo privado em comandos, relatório ou PR.

| Grupo | Variáveis e decisão |
| --- | --- |
| Identidade | SECRET_KEY aleatório, exclusivo; pelo menos 50 caracteres. Não reutilizar chave local/CI. |
| Público | PUBLIC_HOST, FRONTEND_PUBLIC_ORIGIN, ALLOWED_HOSTS explícitos, sem wildcard; CORS_ALLOWED_ORIGINS e CSRF_TRUSTED_ORIGINS somente HTTPS necessárias. |
| Proxy | TRUSTED_PROXY_CIDRS=10.85.0.10/32 no Compose; ajustar se a topologia mudar. Nunca confiar em toda internet. |
| Banco/cache | DATABASE_URL do papel restrito; CACHE_URL Redis privado. Banco/cache não publicam portas no host. |
| E-mail | SMTP real, remetente autorizado, usuário/senha juntos. 587+TLS **ou** 465+SSL; nunca os dois. Timeout de 1 a 30 s, padrão 10. |
| Recuperação | Link para `#/recuperar-senha/{uid}/{token}`; padrão 1800 s. Não configurar URL de POST como destino do e-mail. |
| Piloto | PILOT_CIDRS reais da equipe, TLS_CONTACT_EMAIL e PRIVACY_CONTACT_EMAIL válidos. Valor de documentação 192.0.2.1/32 não concede acesso real. |
| Dados | MEDIA_ROOT, DELETION_JOURNAL_DIR, SECURE_LOG_DIR e BACKUP_ROOT persistentes/protegidos; o diário precisa de cópia independente atual. |
| Geografia | Provedores existentes preservados. Nominatim continua opt-in; configurar instância/política e Redis antes de habilitar. Falhas externas não viram locais fictícios. |

`API_BASE_URL` compilado no Flutter é público. Não compilar segredo, senha de
banco, token privado ou chave de provedor nele.

## Windows: continuar pelo navegador

Na raiz do projeto, após aplicar o pacote:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements-catalog.txt -r backend/requirements-geographic.txt
Copy-Item .env.example .env
# Edite .env: chave local e contato/SMTP de captura, sem contas reais.
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

Em outro terminal, mesma venv: `python manage.py process_account_mail --watch`.
Use SMTP de captura local na porta 1025 para contas sintéticas; apenas aceitar
a solicitação não significa que o e-mail foi enviado. Sem transporte, o job
falha e pode ser retomado; não utilizar backend de memória fora dos testes para
simular entrega. Leia o link na caixa de captura privada, sem publicar o token.

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 7357 --dart-define=API_BASE_URL=http://localhost:8000
```

Abra `http://localhost:7357`. Se precisar de web-server, use
`flutter run -d web-server --web-port 7357` e essa mesma origem. Android SDK não
é requisito para executar Web. Build APK e o salvamento nativo precisam de
outra máquina/CI com SDK. Android pode concluir recuperação no navegador pelo
mesmo link HTTPS; não se promete um deep link nativo não configurado.

## Implantação de referência

Responsável operacional deve aprovar domínio, DNS, portas 80/443, credenciais,
restrição do piloto e destino externo protegido. Esta entrega não publica,
contrata serviços ou altera conta real automaticamente.

1. Aponte DNS para o host de homologação. Permita publicamente somente 80/443;
   proteja acesso administrativo do host. Revise os CIDRs do piloto.
2. Compile Web com a origem real da API:

```powershell
cd frontend
flutter build web --dart-define=API_BASE_URL=https://staging.seu-dominio.example
cd ..
```

3. No host com Docker/Compose, crie destino de backup privado 0700 e carregue o
   arquivo privado explicitamente:

```sh
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml build
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml up -d db cache
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml run --rm app python manage.py migrate --noinput
# SOMENTE no primeiro piloto vazio. Em recuperação, repor o diário original atual.
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml run --rm app python manage.py init_privacy_journal --new-pilot
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml run --rm app python manage.py collectstatic --noinput
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml run --rm app python manage.py check --deploy
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml up -d app mail maintenance proxy
```

O proxy aguarda app pronto. Volumes retêm PostgreSQL, mídia, diário, logs,
estáticos e certificados. **Não usar `down -v`**, pois remove os volumes.
O initdb cria papel `acessoja_app` sem SUPERUSER/CREATEDB/CREATEROLE, separado do
administrador. Migrações usam esse papel dono das tabelas. Clientes de backup
usam PostgreSQL 16 compatível com o servidor 16.15 da referência.

Caddy obtém certificado público no host real. Restrição IP inclui Admin/docs.
O app/proxy executam com UID 10001; diretórios privados 0700. O proxy remove
Forwarded/X-Forwarded-* fornecidos e reescreve protocolo/IP. Django descarta
cabeçalhos de fontes não confiáveis. API usa token; cookies Admin são secure,
HttpOnly onde aplicável e CSRF mantém validação de origem. CORS não autoriza
usuário nem substitui CSRF.

HSTS é de uma hora, sem includeSubDomains/preload até auditoria de domínio.
`check --deploy` em perfil restrito reporta W005 e W021 por essas duas decisões;
os avisos permanecem visíveis. Habilitar as opções somente quando todos os
subdomínios e as condições de preload forem verificados.

O Web tem fallback para index.html, inclusive acesso direto à recuperação.
Mídia privada/diário/backup não têm file_server público. Não há upload de
avaliações introduzido por estes cards. Validar na instalação que não há
conteúdo misto nem ciclos de redirects.

Para comandos fora do container com arquivo privado explícito:

```powershell
python scripts/staging_command.py --env-file C:\seguro\staging.env python manage.py check --deploy
```

## Logs, prontidão e observação

App registra evento/status/duração/correlação; formatter ignora mensagens,
exceções, corpos, headers e URLs. Proxy filtra o request inteiro e headers de
resposta; não duplicar logs brutos no Docker. SMTP não usa modo debug. No piloto,
os logs ficam no volume privado, acessível somente à operação.

**Ativar** no host `deploy/staging/logrotate.conf`, ajustando o caminho para o
volume real. Política diária, maxage/rotações dentro de 14 dias. `copytruncate`
evita manter inode aberto, mas pode perder linhas durante rotação; usar retenção
privada centralizada se a operação exigir preservação estrita. Caddy também
limita tamanho/idade; maintenance remove arquivos antigos e metadados vencidos.
Sem ativar rotação do host, não considerar o prazo de logs validado.

- `/health/live/`: processo, sem detalhes internos.
- `/health/ready/`: banco, canário de cache, diário em homologação e fila de
  e-mail sem atraso superior a cinco minutos; dependência obrigatória falha →503.
- `mail --watch` envia e-mails; `maintenance --watch` reconcilia recibos,
  expurga jobs/consentimentos/logs administrativos vencidos e sessões.

Agende um probe privado a cada minuto pelo scheduler do host:

```sh
python scripts/probe_readiness.py --url https://staging.seu-dominio.example/health/ready/
python scripts/summarize_secure_logs.py /CAMINHO_PRIVADO/app.json.log /CAMINHO_PRIVADO/probes.json.log
```

O probe emite só status, duração e healthy; exit 1 indica falha. Agendamento,
armazenamento/rotação da saída e encaminhamento do alerta à pessoa responsável
são etapas operacionais pendentes. Resumo oferece erros/latência p95/probes;
não estabelece disponibilidade de 99% nem comprova meta de carregamento <2 s.
Teste uma parada de dependência **isolada**, observe 503 e recuperação, sem
parar banco compartilhado/real automaticamente.

Laboratório local reproduzível, com Gunicorn+Caddy instalados e CA temporária
não adicionada à confiança do sistema:

```sh
python scripts/verify_proxy_lab.py --caddy /CAMINHO/caddy --report /DIRETORIO_PRIVADO/proxy-lab.json
```

Este teste usa dependência indisponível deliberadamente; o relatório separa seu
escopo da infraestrutura externa.

## Backup e restauração

Política proposta: backup diário e antes de migração; retenção restaurável de
14 dias; responsável da operação nominal antes do piloto. Armazenar cópia fora
do host com acesso restrito e criptografia do armazenamento/transporte. Não
salvar .env/segredos junto ao dump. Agendamento, replicação e expurgo de backups
vencidos precisam ser ativados e verificados pela operação.

O diário de exclusões é independente do dump, com cópia **atual** fora do host.
Nunca restaurá-lo a partir do bundle antigo. Marcador ausente/substituído ou
intenção pendente bloqueia restauração; marcador não detecta uma cópia antiga
consistente. Sem garantia de diário atual, manter banco restaurado isolado.
Recibos ficam por pelo menos 35 dias e até expirar o último backup
correspondente; não há expurgo automático cego desses recibos.

```sh
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml exec maintenance python manage.py sync_privacy_deletions --authoritative-live-database
docker compose --env-file /etc/acessoja/staging.env -f deploy/staging/compose.yaml --profile ops run --rm backup backup --destination /backups
```

Bundle privado: custom dump PostgreSQL + tar de mídia + manifesto SHA-256,
fingerprint da aplicação e contagens na mesma snapshot exportada do dump.
Diretório 0700, arquivos 0600; diretório incompleto só é renomeado após sucesso.
Ter esse bundle **não comprova restauração**.

Restauração requer PostgreSQL vazio cujo nome comece `acessoja_restore_` e
diretório de mídia novo, separado e com esse prefixo. Não expor o banco à API do
piloto, não substituir o banco ativo. Usar a mesma revisão do código; diferenças
de fingerprint, checksum, idade >14 dias, diário ou contagens bloqueiam o processo.

Crie o banco isolado pela operação com papel adequado e informe
`RESTORE_DATABASE_URL` num arquivo privado separado. A DATABASE_URL continua
identificando a origem, para impedir restaurar sobre ela. Exemplo após carregar
o arquivo privado com `staging_command.py`:

```sh
python scripts/staging_backup.py restore --bundle /backups/IDENTIFICADOR --media-target /backups/acessoja_restore_media
```

O script conecta ao destino isolado antes de carregar Django, restaura,
verifica contagens/migrations/check, reaplica exclusões e remove todos os tokens,
sessões e jobs restaurados. Relatório privado registra duração e contagens antes/
depois, sem linhas pessoais. Rejeita links e travessia no tar. Uma falha deixa
o destino para inspeção, nunca promove automaticamente. Após resolver a causa,
recrie um destino vazio distinto; não reutilize parcialmente restaurado.

Para validar autenticação e fluxos, inclua previamente no backup uma conta
`synthetic-*` com e-mail `@example.test` e carregue a senha somente em
`SYNTHETIC_SMOKE_PASSWORD` privado. No ambiente **do destino**:

```sh
python manage.py smoke_account_security --synthetic-isolated --user synthetic-verificacao
```

O smoke só aceita PostgreSQL `acessoja_restore_*`; testa login, exportação,
reset/e-mail em memória, rejeição de senha/link/credencial antigos, novo login e
exclusão da conta sintética. Usa diário temporário próprio; não contamina o diário
do piloto. Depois valide mapa, favoritos e integridade com dados sintéticos.
O CI contém teste real de dump/restore/supressão/smoke; se PostgreSQL não existir
na máquina, ele fica skipped e **não conta como restauração aprovada**.

## Atualização, rollback e pendências externas

Antes de atualizar: registrar revisão, backup e teste de restauração; pausar
escritas de conta se necessário, aplicar migrations, coletar static, atualizar
app/workers/Web juntos e testar. Não executar PR/merge/deploy automaticamente.

Migrations adicionam UUID por usuário, consentimentos, fila/recibos e alteram o
criador legado para SET_NULL. Embora o schema possa ser revertido, remover as
tabelas/UUID/recibos perde proteção de exclusões; **não fazer rollback dessas
migrations com dados do piloto**. Preferir correção adiante. Uma aplicação antiga
não entende a pausa de consentimentos nem as novas regras; não reexpor essas
rotas ao voltar versão. Recuperação por backup precisa primeiro reaplicar o
diário atual em banco isolado; não restaurar senhas/sessões excluídas.

Antes de aceitar Card 37, falta executar no ambiente real: DNS/certificado e
URLs; entrega SMTP em conta de teste; restrição Admin/docs/IP; persistência após
recriação; rotação/retenção de logs; probe/alerta; backup externo diário, expurgo,
restauração isolada com duração/integridade/smoke; cópia atual do diário;
responsáveis, controle de acesso e decisões do controlador. Validar ainda
Android com SDK/dispositivo e leitor de tela real. Manter piloto com dados
sintéticos até essas verificações.

Referências: [Django 5.2 deployment checklist](https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/),
[Caddy headers](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy),
[PostgreSQL pg_dump](https://www.postgresql.org/docs/16/app-pgdump.html) e
[pg_restore](https://www.postgresql.org/docs/16/app-pgrestore.html).


## Fotografias e avatar — Cards 42 a 46 (27/10/2026)

Integração real de imagens de avaliações e perfil, com processamento Pillow, armazenamento privado persistente e revisão/moderação. Aplicar as migrations do pacote e usar Flutter 3.47.4 (image_picker 1.2.4; Dart mínimo 3.11). Avatares legados continuam base64. Limite por arquivo 5 MiB; corpo multipart 6.000.000 bytes somente nas novas rotas, sem abertura pública de /media.

- [Fotos e galeria](FOTOGRAFIAS_AVALIACOES_CARDS_42_43.md)
- [Foto de perfil](FOTO_PERFIL_CARD_44.md)
- [Instalação Windows, limites, limpeza, proxy, backup e rollback](MIDIA_SEGURA_CARD_45.md)
- [Evidências, resultados e pendências reais](EVIDENCIAS_CARD_46.md)
- [Adendo às seções 20/22/24/25 e planejamento](ESPECIFICACAO_CARDS_42_46.md)

Para backup com mídia, é obrigatória janela sem escritores, inclusive sem worker de limpeza, conforme o procedimento do Card 45. Não considerar pg_dump e cópia online dos arquivos um snapshot conjunto. A homologação em aparelho Android/Chrome móvel e PostgreSQL precisa das execuções pendentes descritas nas evidências.

# AcessoJá — Preparação reproduzível do ambiente local

Este documento complementa o Card 34 e os Cards 35–41. O código, o catálogo
público e o *nome* do moderador podem ser versionados; **senhas, chaves,
bancos pessoais, avaliações, sessões, histórico de rotas e denúncias não**.

## 1. Primeiro PC, única vez: exportar os locais que já estão no banco

Na raiz `C:\Users\User\acessoja-cards38-41`, com `.env` apontando para
`sqlite:///./.venv/cards38_41_com_osm.sqlite3`, pare a API por segurança,
e rode:

```powershell
$py = '.\.venv\Scripts\python.exe'
& $py manage.py shell -c "from django.conf import settings; from locais.catalog_models import CatalogEntry, CatalogScope; print('BANCO:', settings.DATABASES['default']['NAME']); print('OSM:', CatalogEntry.objects.count()); print('ATIVO:', list(CatalogScope.objects.values_list('active_batch_id', flat=True)))"
& $py manage.py exportar_catalogo_demo --saida dados_iniciais/catalogo_anapolis.json
& $py manage.py carregar_catalogo_demo --arquivo dados_iniciais/catalogo_anapolis.json --verificar
Get-Item dados_iniciais/catalogo_anapolis.json | Select-Object Name,Length
```

**Verifique:** cerca de 423 registros no OSM (o endpoint pode retornar 422
não vinculados + um Local comunitário); `sha256` válido; fonte OSM,
snapshot e licença ODbL preservados. Esse JSON **ainda não está incluído no
ZIP**: os 423 registros estão no banco do usuário, e o exportador precisa
ser executado lá. O arquivo fica no Git depois do comando `git add`.

O exportador não usa `dumpdata` do banco inteiro e exclui `Usuario`, `Local`,
avaliações, denúncias, credenciais, vínculos de identidade comunitária e
informações privadas. Inclui somente `CatalogBatch` (metadados mínimos),
`CatalogPOI` (identidade OSM) e `CatalogEntry` (observações do catálogo).
O hash SHA-256 detecta corrupção acidental do conteúdo versionado.

## 2. Novos PCs / clones

Depois de fazer `git clone` da branch com os Cards 34–41 e com o JSON
versionado, no Windows com Python 3.12 e Flutter disponíveis, execute:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preparar_pc_novo.ps1
```

Esse script cria `.venv` se ausente, instala dependências, prepara `.env`
**somente se não existir** (gerando chave secreta aleatória neste PC), aplica
migrations, carrega catálogo OSM e prepara o moderador; roda também
`flutter pub get` quando o SDK estiver disponível. Nunca sobrescreve `.env`
existente. O PowerShell não envia segredos ao Git. Quem já tem `.venv` e
`.env` configurados pode rodar somente:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preparar_pc_local.ps1
```

O script aplica migrations; quando o JSON versionado está presente, carrega
uma única vez o catálogo completo, sem PBF/Overpass. Também cria o usuário
**qa_moderador** caso ainda não exista, com `is_staff=True`,
`is_superuser=False` e a permissão específica `evidencias.moderate_content`.
**A conta nova começa sem senha utilizável e não pode efetuar login.**
Defina uma senha forte apenas no seu PC com:

```powershell
& .\.venv\Scripts\python.exe manage.py changepassword qa_moderador
```

Em PCs já configurados a senha existente **nunca é modificada** e repetir o
bootstrap não duplica o usuário, o grupo ou os locais. Jamais inclua uma
senha padronizada ou o hash da senha no Git, e não dê superuser automático.
O comando de preparação do moderador recusa execução em staging/produção.

Para preparar somente os estabelecimentos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preparar_pc_local.ps1 -SemModerador
```

Para revisar primeiro o JSON:

```powershell
& .\.venv\Scripts\python.exe manage.py carregar_catalogo_demo --verificar
```

### Se a base já tem um catálogo OSM ativo

O importador não sobrescreve lotes existentes. Se o lote ativo e os registros
são os mesmos, informa `already_installed`. Se são diferentes, falha com
mensagem para que a atualização seja analisada manualmente. **Não apague o
banco atual só para executar o seed.** Para testar o seed no PC 1, use uma
base nova específica da demonstração.

## 3. Configurações relevantes que não devem exigir retrabalho

- **Admin 403 CSRF:** em `acessoja/security_settings.py`, usar
  `SECURE_REFERRER_POLICY="same-origin"`. Manter `CsrfViewMiddleware`; não
  confiar em `Origin: null`, não desligar CSRF.
- **Projeto e banco:** ao abrir outro PowerShell, o ambiente anterior não
  é mantido. Ativar `.venv` ou usar `& .\.venv\Scripts\python.exe`. O
  `.env` deve apontar sempre para o banco esperado. Confirmar com
  `python manage.py shell` antes de aplicar migrations ou testar.
- **Flutter Web:** `flutter pub get`, `flutter analyze`, `flutter test`,
  `flutter run -d chrome --web-port 7357 --dart-define=API_BASE_URL=http://127.0.0.1:8000`.
- **OSM:** não baixar o PBF de ~207 MB ou repetir a importação em cada PC.
  A busca externa Overpass pode falhar (502/504) e não deve ocultar o
  catálogo versionado. Clique em **Carregar os locais restantes** para
  carregar além da primeira página de 20 POIs; há clusters no mapa.
- **GPS:** localização aproximada do Windows não comprova precisão para
  iniciar navegação. O controle de navegação exige posição recente (30 s)
  e precisão de até 50 m. Testar em Android físico quando possível;
  origem manual permite prévia e traçado, não navegação real.
- **E-mail:** `configure-gmail.ps1` grava credencial SMTP **somente** no
  `.env` local. O login SMTP não foi validado neste PC; recuperação de
  senha real continua pendente. Para desenvolvimento isolado, pode-se
  configurar backend console e usar `process_account_mail --watch`.
- **Admin do Django:** `http://127.0.0.1:8000/admin/` (não abrir embutido).
  `qa_moderador` é uma conta de **teste local**, nunca um usuário automático
  compartilhado para produção.
- **Qualidade:** executar `python manage.py check`,
  `python manage.py makemigrations --check --dry-run`,
  `pytest -q --cov=. --cov-fail-under=80`, `flake8`, `flutter analyze`,
  `flutter test`, `flutter build web` antes do PR. PostgreSQL/Redis são
  validados por jobs específicos do CI, não por testes SQLite.

## 4. Git seguro

```powershell
git status --short
git add locais/services/catalog_seed_demo.py locais/management/commands/exportar_catalogo_demo.py locais/management/commands/carregar_catalogo_demo.py locais/test_catalog_seed_demo.py usuarios/management/commands/preparar_moderador_demo.py usuarios/test_preparar_moderador_demo.py scripts/preparar_pc_local.ps1 docs/PREPARACAO_REPRODUZIVEL_PC.md dados_iniciais/catalogo_anapolis.json acessoja/security_settings.py
git diff --cached --check
git diff --cached --stat
```

Revisar a lista antes de `commit`. Nunca executar `git add -A` sem revisão,
nem versionar `.env`, `*.sqlite3`, tokens, `private-media/`, logs, backups,
`*.pbf`, `.venv/`, relatórios sensíveis ou dados reais de contas.

Dados OSM: © OpenStreetMap contributors, ODbL 1.0 —
https://www.openstreetmap.org/copyright. Separar o arquivo público das
contribuições de usuários ajuda a controlar a origem e os direitos; ainda
é necessário cumprir as obrigações da ODbL aplicáveis.

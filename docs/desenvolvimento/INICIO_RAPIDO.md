# Instalação, execução e desenvolvimento — AcessoJá

**Sistemas:** Windows PowerShell (scripts oficiais) e execução manual em outros sistemas. Atualizado editorialmente em 2026-11-01 com base no README de `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5`.

## Pré-requisitos

- Python 3.12.
- Flutter 3.47.4 / Dart da mesma distribuição (`frontend/.fvmrc`). FVM é recomendado.
- Java 17 para Android; SDK/NDK compatíveis com o app (consulte `frontend/android`).
- SQLite serve para o ambiente inicial local; PostgreSQL é configurável por `DATABASE_URL`.

## Instalação no Windows (PowerShell)

```powershell
git clone https://github.com/acessoja/acessoja-app.git
cd acessoja-app
.\scripts\setup-dev.ps1
```

O script verifica ferramentas, instala dependências e prepara o ambiente local segundo as verificações implementadas no arquivo. Ele não deve ser interpretado como instalador de ferramentas externas ausentes. **Atenção:** também verifica a cadeia Android (SDK/NDK) e pode encerrar com erro se esses componentes não estiverem instalados, mesmo quando o objetivo for usar somente o navegador. Para um computador Web-only, use o procedimento específico abaixo.

## Alternativa Windows — somente Flutter Web/Chrome, sem Android SDK

Este procedimento é útil para homologação no navegador quando Python 3.12 e Flutter 3.47.4 estão instalados, mas o Android SDK/NDK não está disponível. **Não execute `setup-dev.ps1` como pré-requisito desse caminho:** o script exige verificações Android que não são necessárias para a Web.

No **PowerShell**, a partir da raiz do repositório:

```powershell
# Após clonar e entrar na pasta acessoja-app:
python -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements.txt

# Crie o .env apenas se não existir; preserve configurações locais:
if (-not (Test-Path .env)) { Copy-Item .env.example .env }

# Gere uma chave local para uso exclusivo neste ambiente:
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# ATENÇÃO: copie manualmente a chave gerada para a linha SECRET_KEY=
# do arquivo .env. Substitua o valor de exemplo. Nunca divulgue a chave,
# nem a registre em commits, prints ou logs de suporte.

# Somente depois de salvar e conferir o .env, prepare o banco:
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

A última instrução mantém o terminal ocupado. Em **outro PowerShell**, na raiz do projeto:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port=7357 --dart-define=API_BASE_URL=http://localhost:8000
```

O comando acima só foi **conferido documentalmente com os arquivos do repositório**; não há registro de execução real no Windows nesta entrega. O ambiente Web não substitui a homologação Android física.

## Banco vazio e catálogo municipal de Anápolis

`python manage.py migrate` cria as estruturas do banco; a migration `locais/0011_municipal_catalog` **não importa automaticamente os estabelecimentos**. Por isso, depois de instalar o projeto, um mapa vazio pode significar apenas ausência de dados de demonstração.

O repositório contém o snapshot público `dados_iniciais/catalogo_anapolis.json` e o comando Django `carregar_catalogo_demo`. Para um **banco local de desenvolvimento/teste**, a partir da raiz e com o ambiente ativado:

```powershell
# Valide o arquivo sem alterar o banco:
python manage.py carregar_catalogo_demo --verificar

# Somente após conferir o ambiente e a origem dos dados:
python manage.py carregar_catalogo_demo
```

A importação pode recusar substituir um lote ativo ou interferir em contribuições existentes. **Não execute a carga sobre banco real, compartilhado ou de produção sem procedimento aprovado**. O objetivo do snapshot é habilitar a conferência do catálogo municipal em um ambiente controlado. Consulte [`docs/CATALOGO_OSM_ANAPOLIS.md`](../CATALOGO_OSM_ANAPOLIS.md) para regras e limitações.

## Iniciar serviços no Windows (PowerShell)

```powershell
.\scripts\dev.ps1
# alternativamente
.\scripts\dev.ps1 -BackendOnly
.\scripts\dev.ps1 -FrontendOnly
# selecione o dispositivo quando necessário
.\scripts\dev.ps1 -Device ID_DO_DISPOSITIVO
```

## Execução manual (a partir da raiz)

```bash
python -m venv venv
# Linux/macOS
source venv/bin/activate
pip install -r backend/requirements.txt
cp .env.example .env
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

No Windows PowerShell, use `.\venv\Scripts\Activate.ps1` para ativar o ambiente e `Copy-Item .env.example .env` em vez de `cp`. Para um ambiente já configurado, não sobrescreva o `.env` existente.

Gere uma `SECRET_KEY` local e substitua a do arquivo de exemplo antes de uso:

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

**Nunca** inclua `.env`, chaves ou banco local em commit/ZIP. Confirme o uso de SQLite/PostgreSQL no `.env.example` da base efetiva.

Em outro terminal:

```bash
cd frontend
flutter pub get
flutter run -d chrome
# ou para Android/dispositivo conectado:
flutter run
```

## Android e endereço da API

No emulador Android, o host local normalmente é `10.0.2.2`, em vez de `localhost`. Para dispositivo físico, escolha o endereço alcançável na rede, ou configure o redirecionamento ADB com segurança.

```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://IP_DA_MAQUINA:8000
```

Verifique a configuração efetiva em `frontend/lib/config.dart` e não exponha o backend a redes não confiáveis. Evite misturar instruções do emulador com as de aparelho físico.

## API OpenAPI

Com `python manage.py runserver` em execução, consulte:

- Swagger UI: http://localhost:8000/api/docs/
- ReDoc: http://localhost:8000/api/redoc/
- Schema: http://localhost:8000/api/schema/

Exportar o schema:

```bash
python manage.py spectacular --file schema.yaml
```

## Problemas conhecidos e diagnóstico

- `flutter` não localizado: conferir PATH/FVM e versão `frontend/.fvmrc`.
- Erros de JDK no build: confirmar Java 17 e `JAVA_HOME`.
- SDK/NDK ausentes: conferir configuração Android, `local.properties` local e downloads do Gradle.
- `Connection refused`: confirmar backend ativo, porta 8000 e endereço da API adequado ao dispositivo.
- `.env` ausente: criar cópia local de `.env.example`, sem publicar segredos.

## Testes

Veja [`QUALITY.md`](../../QUALITY.md) para a lista de checks configurados no CI. Registre resultados apenas após execução real; um comando listado não é evidência de aprovação.

# Central de Moderação do AcessoJá

O Django Admin serve a Central de Moderação por padrão em `/admin/`. As filas, os detalhes de denúncias e fotos e o histórico usam o mesmo visual, inclusive ao abrir atalhos antigos. O Flutter continua independente da moderação administrativa.

## Abrir no Windows

Na raiz da worktree, com o ambiente local já configurado:

```powershell
cd C:\Users\User\acessoja-listas-181-183
.\scripts\dev.ps1 -BackendOnly -OpenModeration
```

Se o Django já estiver rodando, não suba outro servidor na mesma porta. Abra http://127.0.0.1:8000/admin/ e entre com seu moderador. O início manual existente também serve o novo design:

```powershell
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

No Flutter Web, mantenha o host `localhost` para o frontend e sua API. Use `127.0.0.1` na aba do Admin, ou outro perfil de navegador para evitar misturar sessões durante o teste.

## Preservar dados

- Continue usando a raiz da worktree, o `DATABASE_URL` atual e o diretório atual de mídia privada.
- Esta alteração não tem migrations, importador, reset ou dados de demonstração. O painel lê as avaliações, denúncias, revisões e decisões já gravadas. As imagens continuam saindo da rota protegida do Django.
- Fotos só aparecem se os arquivos correspondentes existirem no armazenamento privado e estiverem disponíveis para essa conta.
- Em staging, publique os arquivos estáticos com o processo usual de `collectstatic`. Não exponha o diretório de mídia privada.
- A área é reservada a conta ativa com acesso ao Admin e permissão `evidencias.moderate_content`, ou superusuário ativo. Não compartilhe senhas ou arquivos de ambiente.

## Validação rápida

```powershell
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py test evidencias.test_admin_presentation favoritos.test_save_list_edits
cd frontend
flutter test --no-pub test/personal_list_icon_picker_test.dart
flutter test --no-pub test/favorites_integration_test.dart --plain-name "main save button creates a colored icon list and saves the selected place"
flutter test --no-pub test/favorites_integration_test.dart --plain-name "Salvar em confirma edição de lista existente somente ao concluir"
```

No navegador, confira a tela inicial, as filas, uma denúncia concluída e a imagem pendente sem registrar uma nova decisão. No app, edite uma lista com o pino em **Salvar em…**, confirme em **Concluir**, reabra e verifique os dados. Teste também o cancelamento antes de concluir.

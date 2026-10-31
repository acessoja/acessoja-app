# Infraestrutura de mídia — Card 45

Revisão final: 28/10/2026 (America/Sao_Paulo).

Preparado em 27/10/2026. Reutiliza banco, volume privado, Redis, revogação, recibos de exclusão e operação do Card 37. Pillow 13.0.0 e image_picker 1.2.4 estão fixados; a base já fixa Flutter 3.47.4/Dart 3.13.3. O mínimo Dart do app é 3.11 devido ao plugin. Não usa serviço externo pago.

## Política aplicada

| Item | Valor |
| --- | --- |
| Entrada | JPEG .jpg/.jpeg, PNG .png, WebP .webp estático; formato decodificado precisa corresponder à extensão/MIME |
| Arquivo | 5 × 1.024 × 1.024 = 5.242.880 bytes; um arquivo por operação |
| Corpo completo novo | 6.000.000 bytes incluindo multipart; Caddy 6MB somente nas duas rotas de upload/novo avatar; demais rotas 3MB |
| Quantidade | Cinco fotos lógicas não excluídas por avaliação; substituição não gasta outra posição |
| Dimensões de entrada | Até 24.000.000 pixels e 12.000 px por lado, antes de carregar pixels |
| Saída | JPEG sem transparência, fundo branco; foto até 2.048 px por lado, avatar até 512; proporção preservada |
| Miniatura | Foto até 320 px por lado; avatar até 160 |
| CPU/memória | Worker subprocess separado; 20 s CPU e 768 MiB de address space em Linux; timeout de parede 25 s no pai; Windows mantém limites bytes/pixels/parede |
| Paralelismo | Um envio ativo por conta; duas vagas de processamento por processo; deploy tem dois workers sync/uma thread |
| Rate limit | Fotos 20/conta/h e 60/IP/h; avatar 15/conta/h e 60/IP/h, com coordenação Redis no deploy |
| Transporte | Cliente até 60 s para envio+leitura combinados; Gunicorn 90 s; lease da reserva 120 s |
| Exportação física | ZIP autenticado/reauth de imagens próprias atuais até 8 MiB, sem URL pública ou token persistente |

HEIC/HEIF, SVG, HTML, GIF, APNG e WebP animado não são aceitos. Para celulares que exportam HEIC, escolher/exportar JPEG ou PNG; a API não promete suportar HEIC. Corrupção, truncamento, MIME/extensão falsos, expansão excessiva ou subprocess encerrado são 422. No cliente, o filtro/validação melhora a experiência; o servidor é a decisão de segurança.

O decoder restringe formatos na abertura, verifica a estrutura, carrega dentro dos limites, aplica orientação EXIF e copia pixels para uma imagem RGB nova. Em seguida recodifica sem EXIF/ICC e gera miniatura. A fixture sintética tem orientação, identificação e GPS; o teste inspeciona imagem e miniatura finais. Não preserva originais brutos no storage. Temporários de entrada/saída ficam em diretório privado e são removidos em finally; chaves finais são UUIDs próprios, sem nome/caminho do usuário.

## Consistência e limpeza

1. Validar credencial e reservar operação/asset preparing sob bloqueio do autor; conferir revisão, quota e operação em andamento.
2. Decodificar e gravar derivados fora de transação, mantendo uma reserva persistente.
3. Revalidar credencial e referências sob bloqueio; só então tornar asset ready e atualizar revisão/avatar/operação atomicamente.
4. Falha marca operação failed e asset sem referência retired, com job de limpeza no banco. Processo interrompido deixa lease expirável; o reconciliador faz a mesma compensação. Nova tentativa usa outra chave/lease e não deixa finalização antiga vencer a nova.
5. Retirada lógica precede exclusão física. Limpeza verifica referências atuais antes de apagar as duas variantes. Uma falha permanece pending com contador de tentativas e pode ser retomada após reinício. Nenhum callback em memória é a única garantia.

Comandos: `python manage.py reconcile_images --limit 50` ou `python manage.py account_maintenance`; o worker de homologação existente chama a reconciliação a cada 60 segundos. Executar até drenar lotes conforme volume, acompanhar pending/attempts por administração técnica protegida. Não apagar diretórios manualmente nem executar o worker autoritativo contra um banco restaurado antes de aplicar os recibos de exclusão vigentes.

## Storage, acesso, cache e privacidade

`MEDIA_ROOT` configura a raiz persistente; os assets ficam em `MEDIA_ROOT/images`. No Compose é o volume `media` em `/var/lib/acessoja/media`, compartilhado por app/manutenção/backup e ausente do proxy. Diretórios 0700 e arquivos 0600 em POSIX; no Windows use ACL restrita à conta do serviço. Recriar storage não cria novo conteúdo: referências e bytes existentes precisam permanecer nesse volume/banco.

Todas as variantes passam pela aplicação. Avatar só do titular; foto pública exige ready + revisão atual aprovada + avaliação atual/válida + autor ativo e visível. Titular/moderador autorizado têm consulta privada controlada. Unknown variant/query string/original/arquivo retirado: 404. GET e HEAD aplicam a mesma decisão. Respostas usam private/no-store, Vary Authorization/Cookie, JPEG, nosniff e CSP sandbox. UUID não concede autorização. Caddy nega /media, /private-media, /private-deletions e /backups por um handle próprio, antes do fallback SPA; não criar file_server público para facilitar a imagem.

O bootstrap Web usa CanvasKit do próprio build para não depender de CDN na inicialização; preserve o diretório canvaskit ao servir os arquivos. Flutter Web faz GET por AppHttp com Authorization, recebe bytes e monta MemoryImage. Não usa token em URL, redirecionamento externo nem Image.network com HTML para contornar CORS. O cache específico guarda até 32 provedores e os remove na troca de conta, atualização/retirada e dispose. Respostas tardias são descartadas por geração/sessão; visualizador privado fecha na troca de conta. Cache HTTP no-store sozinho não é a defesa do widget. Não se promete apagar cópias já baixadas por terceiros.

Exportação de dados inclui metadados próprios de fotos/revisões/operações; `POST /api/usuarios/me/images-export/` com current_password obtém os próprios derivados atuais, inclusive estados privados autorizados, sem conteúdo de terceiros. Exclusão de conta remove referências/avatar, anonimiza contexto/trilhas conforme política dos Cards 36/41 e enfileira todos os assets próprios. Excluir avaliação também sinaliza limpeza, sem alterar imagens alheias.

## Instalação Windows/desenvolvimento

Na raiz existente, depois de aplicar o delta com backup:

```powershell
py -3.12 -m pip install -r backend/requirements.txt -r backend/requirements-catalog.txt -r backend/requirements-geographic.txt
py -3.12 manage.py check
py -3.12 manage.py makemigrations --check --dry-run
py -3.12 manage.py migrate
py -3.12 manage.py reconcile_images
py -3.12 manage.py runserver 0.0.0.0:8000
```

Use a venv já configurada (ou crie/ative uma); não instale no Python global se o projeto usa venv. `.env.example` é modelo, preserve o .env privado existente. Configure FRONTEND_PUBLIC_ORIGIN e CORS_ALLOWED_ORIGINS para a origem exata, por exemplo http://localhost:7357. Segundo terminal:

```powershell
cd frontend
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 7357 --dart-define=API_BASE_URL=http://localhost:8000
```

Para telefone, substitua localhost por host/IP realmente acessível e permitido, preferindo HTTPS de homologação. A origem do telefone precisa estar no CORS; API_BASE_URL é compilada no app/Web e deve apontar para esse servidor. Não copie o `.env`, token ou senha para o Flutter. Teste pelo navegador sem Android SDK; ele só é necessário para compilar/executar o app Android. Para APK, usar Flutter 3.47.4, Java/Android SDK compatíveis, `flutter doctor -v` e `flutter build apk --debug --dart-define=API_BASE_URL=https://ORIGEM_REAL`.

## Homologação, proxy e backup

Manter o Compose e configuração restrita do Card 37. Instalar as novas dependências, aplicar migrations e rebuild dos serviços antes de publicar a interface. Os novos limites já estão no Caddyfile e Gunicorn. Não houve alteração de `camera=()`: o fluxo usa seletor/captura do sistema com image_picker, não getUserMedia. Câmera e permissões reais precisam ser verificadas em aparelho. As origens HTTPS/CORS/CSRF devem corresponder ao piloto; a lab local não comprova DNS/certificado público.

Backup consistente de imagens exige janela sem escritores: impedir novas entradas no proxy; parar app, mail e maintenance; aguardar uploads já em curso ou reconciliar os expirados antes da parada; manter banco/Redis; executar o backup existente no container de ops com o mesmo build/aplicação e o volume de mídia montado somente leitura. O pg_dump e o arquivo de mídia não constituem snapshot conjunto se uploads ou limpeza continuarem em execução. Atualize o roteiro operacional anterior para exigir essa janela. Retomar os serviços após o backup validado. Recibos de exclusão ficam em persistência independente e precisam de replicação própria, jamais ser sobrescritos pelo snapshot antigo.

Restauração: ambiente isolado, mesmo build/fingerprint do manifesto, volumes vazios e sem tráfego/manutenção autoritativa. Validar manifesto/checksums, restaurar banco+mídia pelo procedimento do Card 37 e aplicar os recibos mais novos antes de qualquer acesso. Executar `python manage.py apply_privacy_deletions --isolated-restore` e `python manage.py reconcile_images --limit 1000`, repetir se necessário, verificar arquivos/referências/autorização e só então liberar tráfego e worker. Não reapresentar dados de conta excluída nem publicar upload directory. Restauração PostgreSQL real e ensaio completo do Compose continuam pendentes neste ambiente; evidência separa isso de persistência/reinício SQLite/FS.

Rollback: primeiro bloquear as novas escritas e preservar backup coerente com recibos vigentes; preferir corrigir adiante. Voltar somente frontend é compatível com a leitura base64. Não executar migrations reversas em produção por conveniência: remover tabelas/FKs de mídia perde histórico/referências e deixa arquivos. Restaurar código+banco+mídia do mesmo ponto e reaplicar exclusões atuais em ambiente isolado antes de disponibilizar. O instalador do delta só altera código com backup; não migra banco nem publica serviços.

## Referências verificadas

- https://pub.dev/packages/image_picker/versions/1.2.4 — Android SDK 24+, recuperação Android e XFile.
- https://api.flutter.dev/flutter/widgets/Image/Image.network.html — headers, HTML e cache.
- https://pillow.readthedocs.io/en/stable/reference/Image.html e ImageOps.html — formatos, bomb limits e orientação.
- https://docs.djangoproject.com/en/5.2/topics/security/#user-uploaded-content
- https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
- https://caddyserver.com/docs/caddyfile/directives/request_body
- https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/

# E-mail real com Gmail

Um remetente Gmail pode enviar para usuarios Gmail e Outlook. O projeto ja usa
SMTP e uma fila no banco: nao ha migracao nem mudanca no Flutter para essa configuracao.

## Configurar uma vez

1. Ative verificacao em duas etapas na conta Google do remetente.
2. Crie uma senha de app: https://myaccount.google.com/apppasswords . Se a opcao
   nao existir, consulte https://support.google.com/accounts/answer/185833?hl=pt-BR .
   Algumas contas ou politicas nao permitem senhas de app; nao use a senha normal.
3. Na raiz do projeto, execute no PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process RemoteSigned
.\scripts\configure-gmail.ps1
```

O script pede o remetente e a senha de app sem exibi-la. Atualiza somente EMAIL_*
necessarios e DEFAULT_FROM_EMAIL no .env existente. O .env ja e ignorado pelo Git.
A credencial e armazenada em texto no .env local, como as demais credenciais do projeto.

## Verificar e testar

Reinicie Django para ler o .env. Em um novo PowerShell na raiz do projeto:

```powershell
.\.venv\Scripts\python.exe manage.py check_account_mail
.\.venv\Scripts\python.exe manage.py check_account_mail --to SEU_EMAIL_DESTINO
```

O primeiro comando so verifica configuracao. O segundo envia uma mensagem real
apenas ao endereco informado; repita com seu Gmail e seu Outlook. Aceitacao SMTP
nao garante caixa de entrada: confira spam e a entrega efetiva em cada conta.

Se usou o backend console em um terminal antigo, feche esse terminal ou remova
a substituicao antes de iniciar os processos:

```powershell
Remove-Item Env:EMAIL_BACKEND -ErrorAction SilentlyContinue
```

## Processar e-mails do aplicativo

Em um terminal separado, na raiz do projeto, deixe rodando:

```powershell
.\.venv\Scripts\python.exe manage.py process_account_mail --watch
```

Esse processo existente envia os itens pendentes validos, inclusive pedidos
anteriores ainda validos. Solicite uma nova recuperacao para uma conta cadastrada
e ativa se a anterior expirou. Endereco inexistente nao recebe recuperacao.
Mantenha Django, Flutter e esse processo ativos. O comando de teste nao processa
a fila e nao altera senha ou conta.

## Impacto

- Mensagens de recuperacao e confirmacao de alteracao passam pelo Gmail real.
- Remetente e senha de app sao configuracoes locais, fora do codigo e do Git.
- Novos comandos facilitam configurar e diagnosticar; a fila e suas tentativas
  continuam como implementadas. Nao ha mudanca no banco, API ou interface.
- O link continua usando FRONTEND_PUBLIC_ORIGIN. Com http://localhost:7357,
  abra-o no mesmo PC com o app rodando; para outros dispositivos sera necessaria
  uma URL publica apropriada e configuracao de implantacao.
- Limites, bloqueios e filtros do Gmail continuam aplicaveis. Em producao,
  dimensione um servico de e-mail transacional e mantenha o worker supervisionado.

SMTP Gmail: https://support.google.com/mail/answer/7104828?hl=pt-BR

"""Validate real SMTP configuration; send only with an explicit --to."""
import smtplib
import ssl
from email.utils import parseaddr

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.core.mail import send_mail
from django.core.validators import validate_email


class Command(BaseCommand):
    help = "Verifica SMTP real. --to EMAIL envia uma mensagem de teste (sem processar a fila)."

    def add_arguments(self, parser):
        parser.add_argument("--to", dest="recipient", help="Destinatario do teste real.")

    def handle(self, *args, **options):
        if settings.EMAIL_BACKEND != "django.core.mail.backends.smtp.EmailBackend":
            raise CommandError("Configure EMAIL_BACKEND para django.core.mail.backends.smtp.EmailBackend.")
        host = settings.EMAIL_HOST.strip().lower()
        if not host or host in {"localhost", "127.0.0.1", "::1"}:
            raise CommandError("Configure EMAIL_HOST com o servidor do provedor; o atual e local.")
        if bool(settings.EMAIL_USE_TLS) == bool(settings.EMAIL_USE_SSL):
            raise CommandError("Ative apenas uma opcao: EMAIL_USE_TLS ou EMAIL_USE_SSL.")
        if bool(settings.EMAIL_HOST_USER) != bool(settings.EMAIL_HOST_PASSWORD):
            raise CommandError("Configure usuario e credencial SMTP juntos.")
        sender = parseaddr(settings.DEFAULT_FROM_EMAIL)[1]
        try:
            validate_email(sender)
            if sender.lower().endswith("@localhost"):
                raise ValidationError("local")
        except ValidationError:
            raise CommandError("Configure DEFAULT_FROM_EMAIL com um remetente autorizado pelo provedor.") from None
        recipient = options.get("recipient")
        if not recipient:
            self.stdout.write(self.style.SUCCESS(
                "Configuracao basica valida. Nenhuma conexao ou mensagem realizada. "
                "Use --to EMAIL para testar autenticacao e envio."
            ))
            return
        try:
            validate_email(recipient)
        except ValidationError:
            raise CommandError("Destinatario invalido.") from None
        try:
            count = send_mail(
                "AcessoJa - teste de entrega",
                "Esta e uma mensagem de teste do AcessoJa. Nenhuma senha foi alterada.\n"
                "Se voce recebeu esta mensagem, confirme a pasta em que ela chegou.",
                settings.DEFAULT_FROM_EMAIL, [recipient], fail_silently=False,
            )
        except smtplib.SMTPAuthenticationError:
            raise CommandError("Autenticacao recusada. Confira a credencial e o metodo permitido pelo provedor.") from None
        except (smtplib.SMTPSenderRefused, smtplib.SMTPRecipientsRefused):
            raise CommandError("Provedor recusou remetente ou destinatario. Confira enderecos e permissoes.") from None
        except ssl.SSLError:
            raise CommandError("Falha TLS. Confira porta, TLS/SSL e certificados; nao desative a verificacao.") from None
        except (OSError, smtplib.SMTPException):
            raise CommandError("Falha de conexao ou envio SMTP. Confira servidor, porta e acesso de rede.") from None
        if count != 1:
            raise CommandError("O backend nao confirmou o envio da mensagem.")
        self.stdout.write(self.style.SUCCESS(
            "Mensagem aceita pelo servidor SMTP. Confira caixa de entrada e spam; "
            "aceitacao SMTP nao comprova entrega na caixa de entrada."
        ))

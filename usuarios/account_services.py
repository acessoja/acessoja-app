"""One credential-change service for custom and Djoser API paths."""
from datetime import timedelta
import logging

from django.conf import settings
from django.contrib.auth import password_validation
from django.contrib.auth.tokens import default_token_generator
from django.contrib.sessions.models import Session
from django.db import connection, transaction
from django.db.models import Q
from django.utils import timezone
from djoser import utils
from djoser.email import PasswordChangedConfirmationEmail, PasswordResetEmail
from rest_framework.authtoken.models import Token
from rest_framework.authentication import SessionAuthentication
from rest_framework.exceptions import NotAuthenticated, ValidationError

from .account_serializers import validate_new_password
from .models import AccountMailJob, Usuario
from .security_throttles import SecurityUnavailable

logger = logging.getLogger("acessoja.security")
INVALID_LINK = {"token": ["Link inválido, expirado ou já utilizado. Solicite outro link."]}


def locked_request_user(request):
    """Call inside atomic(): never save an authentication-time ORM snapshot.

    The owner lock orders writes against reset/deletion. Check the credential
    again after acquiring it so an already revoked request cannot mutate data.
    """
    user = Usuario.objects.select_for_update().filter(pk=request.user.pk, is_active=True).first()
    if user is None or user.password != request.user.password:
        raise NotAuthenticated()
    if isinstance(request.auth, Token) and not Token.objects.filter(key=request.auth.key, user=user).exists():
        raise NotAuthenticated()
    if isinstance(getattr(request, "_authenticator", None), SessionAuthentication):
        session = request._request.session
        valid = Session.objects.filter(session_key=session.session_key, expire_date__gt=timezone.now()).exists()
        if not valid or session.get("_auth_user_hash") != user.get_session_auth_hash():
            raise NotAuthenticated()
    return user


def revoke_credentials(user):
    Token.objects.filter(user=user).delete()
    # Django also invalidates session auth hashes on password changes. Delete
    # owner session rows, including pre-migration Admin sessions, on both flows.
    keys = []
    for session in Session.objects.filter(expire_date__gte=timezone.now()).iterator(chunk_size=200):
        if str(session.get_decoded().get("_auth_user_id", "")) == str(user.pk):
            keys.append(session.session_key)
        if len(keys) == 200:
            Session.objects.filter(session_key__in=keys).delete()
            keys = []
    if keys:
        Session.objects.filter(session_key__in=keys).delete()


def enqueue_mail(user, kind):
    return AccountMailJob.objects.create(user=user, kind=kind,
                                         credential_revision=user.credential_revision if user else 0)


@transaction.atomic
def request_password_reset(email):
    if AccountMailJob.objects.filter(state__in=["pending", "sending"]).count() >= settings.ACCOUNT_MAIL_MAX_PENDING:
        raise SecurityUnavailable()
    # All syntactically valid requests do the same lookup + insert. SMTP and
    # expensive password hashing never run in the public request path.
    users = list(Usuario.objects.filter(email__iexact=email.strip(), is_active=True)[:2])
    user = users[0] if len(users) == 1 and users[0].has_usable_password() else None
    enqueue_mail(user, "reset")


def set_locked_password(user, password):
    validate_new_password(password, user)
    user.set_password(password)
    user.credential_revision += 1
    user.last_login = timezone.now()
    user.save(update_fields=["password", "credential_revision", "last_login"])
    password_validation.password_changed(password, user)
    revoke_credentials(user)
    # Durable in the same transaction: SMTP failure cannot undo a changed password.
    enqueue_mail(user, "changed")


@transaction.atomic
def confirm_password_reset(uid, token, password):
    try:
        pk = int(utils.decode_uid(uid))
        if not 0 < pk <= 2147483647:
            raise ValueError
    except (ValueError, TypeError, OverflowError, UnicodeError):
        raise ValidationError(INVALID_LINK) from None
    user = Usuario.objects.select_for_update().filter(pk=pk, is_active=True).first()
    if not user or not user.has_usable_password() or not default_token_generator.check_token(user, token):
        raise ValidationError(INVALID_LINK)
    set_locked_password(user, password)


def reauthenticate(user, password):
    if not user.is_active or not user.check_password(password):
        raise ValidationError({"current_password": ["Senha atual incorreta. Nenhum dado foi alterado."]})


@transaction.atomic
def change_password(user_id, current_password, new_password):
    user = Usuario.objects.select_for_update().get(pk=user_id)
    reauthenticate(user, current_password)
    set_locked_password(user, new_password)


@transaction.atomic
def login_token(name, password):
    user = Usuario.objects.select_for_update().filter(nome=name).first()
    if user is None:
        Usuario().set_password(password)  # Similar password-hash cost for unknown names.
        return None
    if not user.is_active or not user.check_password(password):
        return None
    token, _ = Token.objects.get_or_create(user=user)
    if token.created + timedelta(seconds=settings.AUTH_TOKEN_TTL) <= timezone.now():
        token.delete()
        token = Token.objects.create(user=user)
    user.last_login = timezone.now()
    user.save(update_fields=["last_login"])
    return user, token


def claim_mail_job():
    now = timezone.now()
    with transaction.atomic():
        jobs = AccountMailJob.objects.filter(
            Q(state="pending", available_at__lte=now) | Q(state="sending", lease_until__lte=now)
        ).order_by("pk")
        jobs = jobs.select_for_update(
            skip_locked=True) if connection.vendor == "postgresql" else jobs.select_for_update()
        job = jobs.first()
        if job is None:
            return None
        job.state, job.lease_until = "sending", now + timedelta(seconds=90)
        job.attempts += 1
        job.save(update_fields=["state", "lease_until", "attempts"])
        return job


def deliver_mail_job(job):
    now = timezone.now()
    state, event = "done", "mail_discarded"
    user = Usuario.objects.filter(pk=job.user_id, is_active=True).first() if job.user_id else None
    expired = now - job.created_at > timedelta(seconds=settings.ACCOUNT_MAIL_MAX_AGE)
    if expired:
        state, event = "failed", "mail_expired"
    elif user and (job.kind != "reset" or (user.has_usable_password()
                                           and user.credential_revision == job.credential_revision)):
        try:
            message = PasswordResetEmail if job.kind == "reset" else PasswordChangedConfirmationEmail
            # No HTTP request: origin comes exclusively from validated settings.
            message(context={"user": user, "site_name": "AcessoJá"}).send([user.email])
            event = "mail_sent"
        except Exception:
            state = "failed" if job.attempts >= settings.ACCOUNT_MAIL_MAX_ATTEMPTS else "pending"
            event = "mail_failed"
    AccountMailJob.objects.filter(pk=job.pk, state="sending", lease_until=job.lease_until).update(
        state=state, lease_until=None, available_at=now + timedelta(seconds=min(900, 30 * 2 ** job.attempts)),
    )
    logger.log(logging.WARNING if event != "mail_sent" else logging.INFO, event,
               extra={"security_event": event})
    return state


def process_mail_jobs(limit=100):
    processed = 0
    for _ in range(limit):
        job = claim_mail_job()
        if job is None:
            break
        deliver_mail_job(job)
        processed += 1
    # Successful no-op jobs and delivered mail leave no user-linked history.
    AccountMailJob.objects.filter(state="done").delete()
    return processed

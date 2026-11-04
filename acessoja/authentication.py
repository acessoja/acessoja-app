from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.exceptions import AuthenticationFailed


class ExpiringTokenAuthentication(TokenAuthentication):
    def authenticate_credentials(self, key):
        user, token = super().authenticate_credentials(key)
        if token.created + timedelta(seconds=settings.AUTH_TOKEN_TTL) <= timezone.now():
            token.delete()
            raise AuthenticationFailed("Sessão expirada. Entre novamente.")
        return user, token


class WebSessionAuthentication(SessionAuthentication):
    """Only sessions minted by the Web login may authorize product API calls."""

    def authenticate(self, request):
        if not request.path.startswith(("/api/", "/auth/")):
            return None
        session = request._request.session
        started = session.get("web_login_at")
        if started is None:
            return None
        if timezone.now().timestamp() - started >= settings.AUTH_TOKEN_TTL:
            session.flush()
            raise AuthenticationFailed("Sessão expirada. Entre novamente.")
        result = super().authenticate(request)
        bound_user = request.headers.get("X-Session-User")
        if result and bound_user is not None and bound_user != str(result[0].pk):
            # A different tab rotated the shared cookie. Reject this tab's old
            # identity without destroying the newer server session.
            raise AuthenticationFailed("Sessão alterada em outra aba. Recarregue.")
        return result

    def authenticate_header(self, request):
        return 'Session'


class MediaSessionAuthentication(WebSessionAuthentication):
    """Preserve read-only Admin media previews; product cookies keep Web TTL."""

    def authenticate(self, request):
        if request._request.session.get("web_login_at") is not None:
            return super().authenticate(request)
        user = request._request.user
        if request.method in {"GET", "HEAD"} and user.is_authenticated and user.is_staff:
            return SessionAuthentication.authenticate(self, request)
        return None


# Registered when Django imports the configured authentication classes.
from drf_spectacular.extensions import OpenApiAuthenticationExtension  # noqa: E402


class WebSessionScheme(OpenApiAuthenticationExtension):
    target_class = "acessoja.authentication.WebSessionAuthentication"
    name = "webCookieAuth"

    def get_security_definition(self, auto_schema):
        return {"type": "apiKey", "in": "cookie", "name": settings.SESSION_COOKIE_NAME,
                "description": "Web only: HttpOnly Django session; unsafe methods require X-CSRFToken."}


class MediaSessionScheme(WebSessionScheme):
    name = "adminMediaCookieAuth"
    target_class = "acessoja.authentication.MediaSessionAuthentication"

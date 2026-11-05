from django.urls import path
from rest_framework.routers import DefaultRouter

from .account_views import (
    AccountTokenLoginView,
    AccountTokenLogoutView,
    AccountUserViewSet,
    SessionLoginView,
    SessionLogoutView,
    SessionUserView,
    UsernameAvailabilityView,
)

router = DefaultRouter()
router.register("users", AccountUserViewSet, basename="user")
urlpatterns = router.urls + [
    path("username-availability/", UsernameAvailabilityView.as_view(), name="username-availability"),
    path("token/login/", AccountTokenLoginView.as_view(), name="login"),
    path("token/logout/", AccountTokenLogoutView.as_view(), name="logout"),
    path("session/login/", SessionLoginView.as_view(), name="session-login"),
    path("session/logout/", SessionLogoutView.as_view(), name="session-logout"),
    path("session/me/", SessionUserView.as_view(), name="session-me"),
]

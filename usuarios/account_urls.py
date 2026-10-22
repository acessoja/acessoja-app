from django.urls import path
from rest_framework.routers import DefaultRouter

from .account_views import AccountTokenLoginView, AccountTokenLogoutView, AccountUserViewSet

router = DefaultRouter()
router.register("users", AccountUserViewSet, basename="user")
urlpatterns = router.urls + [path("token/login/", AccountTokenLoginView.as_view(), name="login"),
                             path("token/logout/", AccountTokenLogoutView.as_view(), name="logout")]

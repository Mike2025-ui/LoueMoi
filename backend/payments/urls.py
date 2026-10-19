from django.urls import path
from .views import (
    CreateSubscriptionView,
    SubscriptionStatusView,
    CanContactView,
    jeko_webhook,
    simulate_checkout,
    redirect_success,
    redirect_error,
)

urlpatterns = [
    path("subscriptions/create/", CreateSubscriptionView.as_view(), name="payment-subscription-create"),
    path("subscriptions/status/", SubscriptionStatusView.as_view(), name="payment-subscription-status"),
    path("can-contact/", CanContactView.as_view(), name="payment-can-contact"),
    path("webhook/", jeko_webhook, name="payment-jeko-webhook"),
    path("checkout/simulate/", simulate_checkout, name="payment-checkout-simulate"),
    path("redirect/success/", redirect_success, name="payment-redirect-success"),
    path("redirect/error/", redirect_error, name="payment-redirect-error"),
]


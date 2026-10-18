from rest_framework import serializers
from .models import Subscription


class SubscriptionSerializer(serializers.ModelSerializer):
    is_active = serializers.BooleanField(source="is_currently_active", read_only=True)
    days_remaining = serializers.IntegerField(read_only=True)

    class Meta:
        model = Subscription
        fields = [
            "id",
            "plan",
            "amount",
            "payment_method",
            "reference",
            "status",
            "is_active",
            "days_remaining",
            "started_at",
            "expires_at",
            "created_at",
        ]
        read_only_fields = fields


class CreateSubscriptionSerializer(serializers.Serializer):
    payment_method = serializers.ChoiceField(
        choices=Subscription.PAYMENT_METHOD_CHOICES,
        default=Subscription.METHOD_WAVE,
    )
    payer_phone = serializers.CharField(
        required=False,
        allow_blank=True,
        default="",
    )


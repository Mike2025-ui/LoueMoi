from django.conf import settings
from django.db import models

from properties.models import Property


class Review(models.Model):
    """Correspond à Review côté Flutter (lib/features/reviews/models/review.dart)."""

    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="reviews")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews")
    rating = models.DecimalField(max_digits=2, decimal_places=1, default=5)
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user} → {self.property} ({self.rating})"

from django.contrib import admin

from .models import Reservation


@admin.register(Reservation)
class ReservationAdmin(admin.ModelAdmin):
    list_display = ["property", "user", "rent", "deposit", "advance", "status", "created_at"]
    list_filter = ["status"]

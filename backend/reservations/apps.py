from django.apps import AppConfig


class ReservationsConfig(AppConfig):
    name = 'reservations'

    def ready(self):
        from . import signals  # noqa: F401

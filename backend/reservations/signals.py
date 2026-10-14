"""Notification "réservation confirmée" — déclenchée uniquement quand le
statut passe réellement à "accomplie". Aujourd'hui, le seul chemin qui
positionne ce statut est Django Admin (aucune action API dédiée n'existe
pour "confirmer" une réservation — voir l'audit de cette mission) : un
signal est donc la façon la plus propre de couvrir CE chemin sans en
inventer un nouveau, et sans dupliquer la notification si un futur code
(API, script...) modifie aussi ce statut."""

from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from .models import Reservation


@receiver(pre_save, sender=Reservation)
def _capture_previous_status(sender, instance, **kwargs):
    if not instance.pk:
        instance._previous_status = None
        return
    try:
        instance._previous_status = Reservation.objects.get(pk=instance.pk).status
    except Reservation.DoesNotExist:
        instance._previous_status = None


@receiver(post_save, sender=Reservation)
def _notify_on_confirmation(sender, instance, created, **kwargs):
    if created:
        return
    previous_status = getattr(instance, "_previous_status", None)
    if previous_status == "accomplie" or instance.status != "accomplie":
        return

    # Imports locaux : évite un import circulaire au chargement de l'app
    # (notifications importe properties/reservations/messaging).
    from notifications.models import Notification
    from notifications.services import NotificationService

    NotificationService.notify(
        recipient=instance.user,
        notif_type=Notification.TYPE_RESERVATION_CONFIRMED,
        title="Réservation confirmée",
        body=f"Votre réservation pour « {instance.property.title} » a été confirmée.",
        property=instance.property,
        reservation=instance,
        data={"reservation_id": str(instance.id), "property_id": str(instance.property_id)},
    )

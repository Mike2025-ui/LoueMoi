from django.db import transaction
from django.db.models import Q
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from messaging.models import Conversation
from messaging.serializers import ConversationSerializer
from notifications.models import Notification
from notifications.services import NotificationService

from .models import Reservation
from .serializers import ReservationSerializer


class ReservationViewSet(viewsets.ModelViewSet):
    """/api/reservations/ — correspond à Reservation côté Flutter. Une
    réservation ne change JAMAIS Property.status (voir perform_create) :
    Reservation.status et Property.status sont deux états indépendants,
    chacun contrôlé par son propre acteur (le statut du bien reste toujours
    sous le contrôle exclusif et manuel du propriétaire, PropertyViewSet.
    mark_status)."""

    serializer_class = ReservationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return Reservation.objects.none()
        # Règle de confidentialité stricte :
        # Chaque utilisateur ne voit que les réservations qui le concernent directement :
        # - En tant que client ayant effectué la réservation (user=user)
        # - En tant que propriétaire/agent du bien réservé (property__agent=user)
        # Aucune fuite de données vers des tiers ou d'autres bailleurs/agents.
        # (La vue globale de toutes les réservations appartient exclusivement au Dashboard Django /dashboard/reservations/).
        return Reservation.objects.filter(Q(user=user) | Q(property__agent=user)).distinct()

    @transaction.atomic
    def perform_create(self, serializer):
        property_obj = serializer.validated_data["property"]
        if self.request.user == property_obj.agent:
            raise ValidationError("Vous ne pouvez pas réserver votre propre annonce.")

        # Règle métier : l'utilisateur peut faire plusieurs réservations,
        # mais une seule réservation sur une même publication (annonce).
        has_property_reservation = Reservation.objects.filter(
            user=self.request.user,
            property=property_obj,
        ).exclude(status="annulee").exists()
        if has_property_reservation:
            raise ValidationError("Vous avez déjà effectué une réservation pour cette annonce.")

        reservation = serializer.save(user=self.request.user, status="enCours")


        # CORRECTION MÉTIER : une réservation ne rend plus l'annonce
        # "occupee" automatiquement — Property.status reste inchangé
        # ("disponible" reste "disponible"). Seul le propriétaire réel du
        # bien décide, via PropertyViewSet.mark_status, quand son bien
        # devient occupé (voir properties/views.py::mark_status).

        owner = property_obj.agent

        # L'acteur (le client qui réserve) ne reçoit pas de notification
        # pour sa propre action — seul le propriétaire, qui n'a rien
        # déclenché lui-même, est notifié. Le push (s'il y en a un) n'est
        # tenté qu'après le commit de cette transaction — voir
        # NotificationService.notify. Une erreur FCM ne peut donc jamais
        # faire échouer la réservation.
        NotificationService.notify(
            recipient=owner,
            notif_type=Notification.TYPE_NEW_RESERVATION,
            title="Nouvelle réservation",
            body=f"{reservation.user.first_name} a réservé « {property_obj.title} ».",
            property=property_obj,
            reservation=reservation,
            data={"reservation_id": str(reservation.id), "property_id": str(property_obj.id)},
            actor=self.request.user,
        )

    def perform_destroy(self, instance):
        """DELETE /api/reservations/{id}/ — autorisée uniquement pour une
        réservation annulée."""
        if instance.status != "annulee":
            raise ValidationError("Seules les réservations annulées peuvent être supprimées.")
        user = self.request.user
        if instance.user != user and instance.property.agent != user and not user.is_staff:
            raise PermissionDenied("Vous n'êtes pas autorisé à supprimer cette réservation.")
        instance.delete()

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def cancel(self, request, pk=None):
        """POST /api/reservations/{id}/cancel/ — `status` est en lecture
        seule sur le serializer (source de vérité côté serveur), donc
        l'annulation passe par cette action dédiée plutôt qu'un PATCH brut.

        Réservée au client ayant fait la réservation : le propriétaire du
        bien ne peut jamais annuler la réservation d'un client depuis cette
        action (get_queryset() lui donne accès en LECTURE aux réservations
        sur ses propres biens pour "voir qui a réservé", mais ce n'est pas
        une permission d'écriture — il dispose de ses propres actions
        dédiées, "Marquer occupé"/"Valider"). Une réservation "accomplie"
        est définitive et ne peut plus être annulée ; une réservation déjà
        "annulee" ne peut pas être annulée une seconde fois (sans ce garde-
        fou, un double appel — double-clic, requête rejouée — renvoyait à
        chaque fois les notifications d'annulation).

        Ne touche plus jamais Property.status : comme pour la création
        (voir perform_create), le statut du bien reste sous le contrôle
        exclusif et manuel du propriétaire (PropertyViewSet.mark_status) —
        annuler une réservation ne doit pas "deviner" qu'il faut remettre le
        bien disponible, d'autant qu'il peut y avoir d'autres réservations
        en cours sur le même bien."""
        reservation = self.get_object()
        if reservation.user_id != request.user.id:
            raise PermissionDenied("Seul le client ayant fait cette réservation peut l'annuler.")
        if reservation.status == "accomplie":
            raise ValidationError("Une réservation accomplie ne peut plus être annulée.")
        if reservation.status == "annulee":
            raise ValidationError("Cette réservation est déjà annulée.")

        reservation.status = "annulee"
        reservation.save(update_fields=["status"])

        property_obj = reservation.property
        actor = request.user

        # Que ce soit le client ou le propriétaire qui annule, seule
        # l'autre partie est notifiée — NotificationService.notify()
        # ignore silencieusement le cas recipient == actor, donc les deux
        # appels ci-dessous couvrent les deux sens sans branchement manuel.
        NotificationService.notify(
            recipient=reservation.user,
            notif_type=Notification.TYPE_RESERVATION_CANCELLED,
            title="Réservation annulée",
            body=f"Votre réservation pour « {property_obj.title} » a été annulée.",
            property=property_obj,
            reservation=reservation,
            data={"reservation_id": str(reservation.id), "property_id": str(property_obj.id)},
            actor=actor,
        )
        if property_obj.agent_id != reservation.user_id:
            NotificationService.notify(
                recipient=property_obj.agent,
                notif_type=Notification.TYPE_RESERVATION_CANCELLED,
                title="Réservation annulée",
                body=f"Une réservation pour « {property_obj.title} » a été annulée.",
                property=property_obj,
                reservation=reservation,
                data={"reservation_id": str(reservation.id), "property_id": str(property_obj.id)},
                actor=actor,
            )

        return Response(self.get_serializer(reservation).data)

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def complete(self, request, pk=None):
        """POST /api/reservations/{id}/complete/ — le propriétaire du bien
        valide la réservation (fin de location/vente réalisée) : passage à
        "accomplie". Réservé au propriétaire réel du bien, jamais au client
        ni à un autre agent/bailleur (même filtrage que `conversation` et
        `mark_status`) — c'est le seul chemin API qui manquait pour ce
        statut (auparavant accessible uniquement via Django Admin, voir
        reservations/signals.py).

        Idempotent : rappeler cette action sur une réservation déjà
        accomplie ne fait rien de plus (ne redéclenche pas la notification,
        qui n'est envoyée par le signal que sur une vraie transition). Une
        réservation annulée ne peut jamais être marquée accomplie — c'est
        une transition invalide (l'annulation est définitive)."""
        reservation = self.get_object()
        property_obj = reservation.property
        if property_obj.agent_id != request.user.id:
            raise PermissionDenied("Seul le propriétaire du bien peut valider cette réservation.")
        if reservation.status == "annulee":
            raise ValidationError("Une réservation annulée ne peut pas être marquée accomplie.")

        if reservation.status != "accomplie":
            reservation.status = "accomplie"
            reservation.save(update_fields=["status"])
            property_obj.status = "accomplie"
            property_obj.save(update_fields=["status"])
            # La notification "réservation confirmée" part automatiquement
            # via le signal post_save existant (reservations/signals.py),
            # qui ne se déclenche que sur une vraie transition vers
            # "accomplie" — jamais dupliquée par un second appel ici.

        return Response(self.get_serializer(reservation).data)

    @action(detail=True, methods=["post"])
    def conversation(self, request, pk=None):
        """POST /api/reservations/{id}/conversation/ — ouvre (ou récupère)
        la conversation entre le propriétaire du bien et le client qui a
        réservé, pour le bouton "Discuter" côté carte de réservation.
        Réservé au propriétaire réel du bien (jamais au client, qui utilise
        déjà "Contacter l'agent" depuis la fiche annonce).

        Conversation.agent n'exige un rôle agent que via
        ConversationSerializer.validate_agent, qui protège uniquement le
        chemin de création public ("Contacter l'agent"). Ici la création
        passe directement par l'ORM : un bailleur propriétaire (rôle non
        agent) peut donc légitimement occuper ce slot, exactement comme
        Property.agent accepte déjà indifféremment agent et bailleur."""
        reservation = self.get_object()
        property_obj = reservation.property
        if property_obj.agent_id != request.user.id:
            raise PermissionDenied("Seul le propriétaire du bien peut contacter ce client.")

        if request.user.role in ("agent", "bailleur") and not request.user.has_active_subscription:
            raise PermissionDenied("Un abonnement actif est requis pour contacter ou discuter avec un client.")

        conversation = Conversation.objects.filter(
            Q(client=reservation.user, agent=property_obj.agent) |
            Q(client=property_obj.agent, agent=reservation.user)
        ).first()

        if not conversation:
            conversation = Conversation.objects.create(
                client=reservation.user,
                agent=property_obj.agent,
                property=property_obj,
            )
        elif property_obj and conversation.property_id != property_obj.id:
            conversation.property = property_obj
            conversation.save(update_fields=["property"])

        serializer = ConversationSerializer(conversation, context={"request": request})
        return Response(serializer.data)

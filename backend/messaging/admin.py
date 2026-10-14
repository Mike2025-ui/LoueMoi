from django.contrib import admin

from .models import Conversation, Message


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ["client", "agent", "property", "created_at"]
    search_fields = [
        "client__phone", "client__first_name", "client__last_name",
        "agent__phone", "agent__first_name", "agent__last_name",
        "property__title",
    ]


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    # Accès réservé à l'administration Django (is_staff requis pour /admin/
    # — voir AdminSite.has_permission) : aucune API publique n'expose le
    # contenu des messages en dehors des participants de la conversation
    # (voir messaging/views.py::MessageListCreateView.get_queryset et
    # MessageAttachmentDownloadView).
    list_display = [
        "conversation",
        "sender",
        "receiver",
        "attachment_type",
        "created_at",
        "is_read",
    ]
    list_filter = ["attachment_type", "is_read"]
    search_fields = [
        "content",
        "sender__phone", "sender__first_name", "sender__last_name",
        "receiver__phone", "receiver__first_name", "receiver__last_name",
    ]

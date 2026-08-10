from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    """Gestionnaire d'utilisateurs avec le téléphone comme identifiant."""

    def create_user(self, phone, password=None, **extra_fields):
        if not phone:
            raise ValueError("Le numéro de téléphone est requis")
        user = self.model(phone=phone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        return self.create_user(phone, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """Utilisateur LoueMoi. Le login se fait par numéro de téléphone,
    conformément à l'écran de connexion Flutter (Numéro Tel + Mot de passe).

    `role` est la SEULE source de vérité pour distinguer client/agent.
    L'administration (Django Admin) reste basée sur `is_staff`/`is_superuser`
    — "admin" n'est jamais un choix exposé à l'inscription publique (voir
    RegisterSerializer.role, qui restreint les valeurs possibles).
    """

    ROLE_CLIENT = "client"
    ROLE_AGENT = "agent"
    ROLE_ADMIN = "admin"
    ROLE_CHOICES = [
        (ROLE_CLIENT, "Client"),
        (ROLE_AGENT, "Agent immobilier"),
        (ROLE_ADMIN, "Administrateur"),
    ]

    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20, unique=True)
    whatsapp = models.CharField(max_length=20, blank=True)
    photo = models.URLField(blank=True, null=True)

    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default=ROLE_CLIENT)

    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    class Meta:
        ordering = ["-date_joined"]

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.phone})"

    @property
    def is_agent(self):
        """Dérivé de `role`, en lecture seule — conservé uniquement pour la
        compatibilité du code existant (limit_choices_to, requêtes internes).
        Ne jamais réintroduire comme champ stocké séparément : `role` est la
        seule source de vérité."""
        return self.role == self.ROLE_AGENT

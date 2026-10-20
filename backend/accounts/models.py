import secrets
import string
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import PermissionsMixin
from django.db import models
from django.utils import timezone


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

    `role` est la SEULE source de vérité pour distinguer
    client/bailleur/agent. L'administration (Django Admin) reste basée sur
    `is_staff`/`is_superuser` — "admin" n'est jamais un choix exposé à
    l'inscription publique (voir RegisterSerializer.role, qui restreint les
    valeurs possibles).

    Bailleur et agent sont deux rôles strictement indépendants : aucune
    délégation, aucun transfert de propriété entre eux. Les deux peuvent
    posséder des annonces (voir Property.agent, dont le nom de colonne est
    conservé pour compatibilité mais qui accepte désormais aussi un
    bailleur — c'est une simple FK vers User, jamais restreinte au niveau
    base de données).
    """

    ROLE_CLIENT = "client"
    ROLE_BAILLEUR = "bailleur"
    ROLE_AGENT = "agent"
    ROLE_ADMIN = "admin"
    ROLE_CHOICES = [
        (ROLE_CLIENT, "Client"),
        (ROLE_BAILLEUR, "Bailleur"),
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
    is_approved = models.BooleanField(
        default=True,
        help_text="Les comptes bailleur et agent doivent être activés par l'administrateur.",
    )
    activation_requested = models.BooleanField(
        default=False,
        help_text="Indique si l'utilisateur a soumis une demande d'activation.",
    )
    activation_requested_at = models.DateTimeField(null=True, blank=True)
    is_verified = models.BooleanField(
        default=False,
        help_text="Badge de certification (agents et bailleurs uniquement).",
    )
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    class Meta:
        ordering = ["-date_joined"]

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.phone})"

    def get_full_name(self):
        return f"{self.first_name} {self.last_name}".strip()

    def save(self, *args, **kwargs):
        # Règle de sécurité stricte : le rôle des clients, agents et bailleurs
        # ainsi que leurs numéros de téléphone ne doivent JAMAIS être modifiables.
        if self.pk:
            orig = User.objects.filter(pk=self.pk).values("role", "phone").first()
            if orig:
                if orig["role"] in (self.ROLE_CLIENT, self.ROLE_AGENT, self.ROLE_BAILLEUR):
                    self.role = orig["role"]
                self.phone = orig["phone"]
        # Les clients non abonnés ne peuvent pas avoir de badge
        if self.role == self.ROLE_CLIENT and not self.has_active_subscription:
            self.is_verified = False
        super().save(*args, **kwargs)
        if self.role == self.ROLE_AGENT:
            profile = getattr(self, "agent_profile", None)
            if profile and profile.is_verified != self.is_verified:
                profile.is_verified = self.is_verified
                profile.save(update_fields=["is_verified"])

    @property
    def is_agent(self):
        """Dérivé de `role`, en lecture seule — conservé uniquement pour la
        compatibilité du code existant (limit_choices_to, requêtes internes).
        Ne jamais réintroduire comme champ stocké séparément : `role` est la
        seule source de vérité."""
        return self.role == self.ROLE_AGENT

    @property
    def is_bailleur(self):
        return self.role == self.ROLE_BAILLEUR

    @property
    def can_own_properties(self):
        """Bailleur et agent peuvent tous deux publier/posséder des
        annonces — deux rôles indépendants, sans hiérarchie entre eux."""
        return self.role in (self.ROLE_AGENT, self.ROLE_BAILLEUR)

    @property
    def has_active_subscription(self):
        """Indique si l'utilisateur possède un abonnement actif non expiré."""
        if not self.pk:
            return False
        from django.utils import timezone
        now = timezone.now()
        if self.subscriptions.filter(status="active", expires_at__gt=now).exists():
            return True
        if self.subscriptions.filter(status="pending").exists():
            try:
                from payments.views import sync_user_pending_subscriptions
                return sync_user_pending_subscriptions(self) is not None
            except Exception:
                pass
        return False


class PasswordResetOTP(models.Model):
    """OTP pour "Mot de passe oublié" (connexion par téléphone, voir
    User.USERNAME_FIELD). Le code lui-même est réel : aléatoire, haché
    (jamais stocké en clair), expire, tentatives limitées — seul l'ENVOI
    par SMS est un bouchon de développement tant qu'aucun fournisseur n'est
    choisi (voir accounts/sms.py)."""

    MAX_ATTEMPTS = 5
    VALIDITY_MINUTES = 10
    REQUEST_COOLDOWN_SECONDS = 60

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="password_reset_otps"
    )
    code_hash = models.CharField(max_length=128)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    is_used = models.BooleanField(default=False)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"OTP pour {self.user} ({'utilisé' if self.is_used else 'actif'})"

    @classmethod
    def generate_for(cls, user):
        """Crée un nouvel OTP et retourne (instance, code_en_clair) — le
        code en clair n'est JAMAIS persisté, seul son hash l'est ; il ne
        doit être utilisé qu'immédiatement pour l'envoi SMS, jamais loggé
        ni renvoyé par l'API."""
        # secrets (pas random) : random.choices() repose sur un générateur
        # pseudo-aléatoire prévisible (Mersenne Twister), impropre à un
        # code de sécurité — secrets.choice() utilise l'aléatoire
        # cryptographique du système d'exploitation.
        code = "".join(secrets.choice(string.digits) for _ in range(6))
        otp = cls.objects.create(
            user=user,
            code_hash=make_password(code),
            expires_at=timezone.now() + timedelta(minutes=cls.VALIDITY_MINUTES),
        )
        return otp, code

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    def check_code(self, code):
        """Incrémente `attempts` à chaque tentative, y compris les échecs —
        limite le brute-force sur un code à 6 chiffres (1 million de
        combinaisons, insuffisant pour se reposer uniquement sur le
        hachage)."""
        self.attempts += 1
        self.save(update_fields=["attempts"])
        if self.is_used or self.is_expired or self.attempts > self.MAX_ATTEMPTS:
            return False
        return check_password(code, self.code_hash)

    def mark_used(self):
        self.is_used = True
        self.save(update_fields=["is_used"])

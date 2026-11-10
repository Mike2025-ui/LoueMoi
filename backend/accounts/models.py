import re
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
        extra_fields.setdefault("role", self.model.ROLE_ADMIN)
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
    last_seen = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Horodatage de la dernière activité pour le statut En ligne / Hors ligne.",
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
        # Règle de sécurité stricte : le rôle des utilisateurs
        # ainsi que leurs numéros de téléphone ne doivent JAMAIS être modifiables.
        if self.pk:
            orig = User.objects.filter(pk=self.pk).values("role", "phone").first()
            if orig:
                if orig["role"] in (self.ROLE_CLIENT, self.ROLE_ADMIN, self.ROLE_AGENT, self.ROLE_BAILLEUR):
                    self.role = orig["role"]
                self.phone = orig["phone"]
        super().save(*args, **kwargs)

    @property
    def is_agent(self):
        return False

    @property
    def is_bailleur(self):
        return False

    @property
    def is_online(self):
        """Indique si l'utilisateur est actuellement actif dans l'application (en ligne).
        Considéré en ligne si sa dernière activité remonte à moins de 2 minutes."""
        if not self.last_seen:
            return False
        return timezone.now() - self.last_seen < timedelta(minutes=2)

    @property
    def can_own_properties(self):
        """Seuls les administrateurs LoueMoi (is_staff / is_superuser / role='admin')
        peuvent publier et gérer des annonces."""
        return bool(self.is_staff or self.is_superuser or self.role == self.ROLE_ADMIN)

    @property
    def has_active_subscription(self):
        """Modèle direct 100% gratuit : aucun abonnement requis."""
        return True


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
        """Crée un nouvel OTP alphanumérique (6 caractères, lettres majuscules et chiffres)
        et retourne (instance, code_en_clair) — le code en clair n'est JAMAIS persisté,
        seul son hash l'est."""
        # Code OTP alphanumérique (A-Z, 0-9) sécurisé par secrets.choice
        chars = string.ascii_uppercase + string.digits
        code = "".join(secrets.choice(chars) for _ in range(6))
        otp = cls.objects.create(
            user=user,
            code_hash=make_password(code),
            expires_at=timezone.now() + timedelta(minutes=cls.VALIDITY_MINUTES),
        )
        return otp, code

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    def check_code(self, code, increment_attempt=True):
        """Vérifie le code OTP alphanumérique insensible à la casse.
        Incrémente `attempts` si increment_attempt est True."""
        if increment_attempt:
            self.attempts += 1
            self.save(update_fields=["attempts"])
        if self.is_used or self.is_expired or self.attempts > self.MAX_ATTEMPTS:
            return False
        clean = re.sub(r"[^a-zA-Z0-9]", "", str(code or "").strip())
        raw_clean = str(code or "").strip()

        return (
            check_password(clean, self.code_hash)
            or check_password(clean.upper(), self.code_hash)
            or check_password(clean.lower(), self.code_hash)
            or check_password(raw_clean, self.code_hash)
            or check_password(raw_clean.upper(), self.code_hash)
        )

    def mark_used(self):
        self.is_used = True
        self.save(update_fields=["is_used"])

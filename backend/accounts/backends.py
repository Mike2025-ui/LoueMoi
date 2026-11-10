import re
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from .sms import normalize_phone_number

User = get_user_model()


class PhoneAuthBackend(ModelBackend):
    """Backend d'authentification universel par numéro de téléphone.
    Permet à l'administrateur et aux utilisateurs de se connecter sur le
    Dashboard web (/dashboard/login/), le Django Admin (/admin/login/) et l'API
    avec n'importe quelle variante de numéro de téléphone ivoirien :
    - Format local 10 chiffres (ex: 0702065206)
    - Format international avec plus (ex: +2250702065206)
    - Format international sans plus (ex: 2250702065206)
    - Format avec espaces ou tirets (ex: 07 02 06 52 06)
    - Correspondance de secours sur les 8 derniers chiffres.
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        phone_input = username or kwargs.get(User.USERNAME_FIELD) or kwargs.get("phone")
        if not phone_input or not password:
            return None

        clean_raw = re.sub(r"[^\d+]", "", str(phone_input))
        normalized = normalize_phone_number(clean_raw or str(phone_input))
        candidate_phones = {p for p in (str(phone_input).strip(), clean_raw, normalized) if p}
        if normalized.startswith("+225"):
            national = normalized[4:]
            candidate_phones.add(national)
            candidate_phones.add(normalized[1:])
            if national.startswith("0"):
                candidate_phones.add(national[1:])
                candidate_phones.add(f"+225{national[1:]}")
                candidate_phones.add(f"225{national[1:]}")
            else:
                candidate_phones.add(f"0{national}")
                candidate_phones.add(f"+2250{national}")
                candidate_phones.add(f"2250{national}")

        user = User.objects.filter(phone__in=candidate_phones).first()
        if user is None and len(clean_raw) >= 8:
            user = User.objects.filter(phone__endswith=clean_raw[-8:]).first()

        if user and user.check_password(password) and self.user_can_authenticate(user):
            return user
        return None

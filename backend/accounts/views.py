from django.contrib.auth import get_user_model
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import RegisterSerializer, UserSerializer

User = get_user_model()


def _auth_payload(user):
    """Construit la réponse attendue par User.fromJson côté Flutter
    (id, first_name, last_name, phone, whatsapp, photo, token)."""
    refresh = RefreshToken.for_user(user)
    data = UserSerializer(user).data
    data["token"] = str(refresh.access_token)
    data["refresh"] = str(refresh)
    return data


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(_auth_payload(user), status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone")
        password = request.data.get("password")
        user = User.objects.filter(phone=phone).first()
        if user is None or not user.check_password(password):
            return Response(
                {"detail": "Numéro de téléphone ou mot de passe invalide."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        return Response(_auth_payload(user))


class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except Exception:
                pass
        return Response(status=status.HTTP_205_RESET_CONTENT)


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

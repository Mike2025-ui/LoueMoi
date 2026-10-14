from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from agents.models import AgentProfile
from properties.models import Property

User = get_user_model()

DEMO_IMAGES = [
    "https://picsum.photos/seed/loue1/800/600",
    "https://picsum.photos/seed/loue2/800/600",
    "https://picsum.photos/seed/loue3/800/600",
]


class Command(BaseCommand):
    help = "Crée un agent démo (vérifié), un client démo et quelques annonces."

    def handle(self, *args, **options):
        agent, created = User.objects.get_or_create(
            phone="+2250700000000",
            defaults={
                "first_name": "Mme Kouakou",
                "last_name": "Marie Therese Ange",
                "whatsapp": "+2250700000000",
                "role": User.ROLE_AGENT,
            },
        )
        if created:
            agent.set_password("password123")
            agent.save()
            self.stdout.write(self.style.SUCCESS(f"Agent créé: {agent.phone} / password123"))
        else:
            self.stdout.write("Agent déjà existant, réutilisé.")

        # is_verified=True ici uniquement parce que c'est un script de seed
        # qui joue le rôle de l'administration — en conditions réelles, seul
        # Django Admin peut vérifier un agent (jamais l'agent lui-même).
        # certification_status="approuvee" en cohérence : les deux avancent
        # toujours ensemble sur le chemin normal (AgentProfileAdmin.
        # approve_certification), jamais l'un sans l'autre.
        AgentProfile.objects.update_or_create(
            user=agent,
            defaults={
                "is_verified": True,
                "certification_status": AgentProfile.CERTIFICATION_APPROVED,
                "rating": 4.8,
            },
        )

        client, created = User.objects.get_or_create(
            phone="+2250712345678",
            defaults={
                "first_name": "Fatou",
                "last_name": "Diallo",
                "whatsapp": "+2250712345678",
                "role": User.ROLE_CLIENT,
            },
        )
        if created:
            client.set_password("password123")
            client.save()
            self.stdout.write(self.style.SUCCESS(f"Client créé: {client.phone} / password123"))
        else:
            self.stdout.write("Client déjà existant, réutilisé.")

        demo_properties = [
            dict(
                title="Appartement meublé",
                description="Bel appartement meublé au coeur de Cocody, proche de toutes commodités.",
                type="logement",
                category="Appartement meublé",
                transaction_type="location",
                price=450000,
                deposit=1230000,
                advance=300000,
                commune="Cocody",
                district="Vallon",
                status="disponible",
                features=["Douche", "Cuisine", "Parking"],
                amenities=["Eau", "Courant"],
            ),
            dict(
                title="Villa haut standing",
                description="Villa haut standing avec finitions modernes, cuisine équipée.",
                type="logement",
                category="Villa",
                transaction_type="location",
                price=1250000,
                deposit=3000000,
                advance=800000,
                commune="Cocody",
                district="Riviera",
                status="disponible",
                features=["Douche", "Cuisine", "Parking", "Jardin"],
                amenities=["Eau", "Courant"],
            ),
            dict(
                title="Terrain à bâtir",
                description="Terrain viabilisé prêt à bâtir, titre foncier disponible.",
                type="terrain",
                category="Terrain",
                transaction_type="vente",
                price=15000000,
                commune="Cocody",
                district="Vallon",
                status="disponible",
                is_future=True,
                features=["Titre foncier"],
                amenities=[],
            ),
        ]

        created_count = 0
        for data in demo_properties:
            _, was_created = Property.objects.get_or_create(
                title=data["title"],
                commune=data["commune"],
                district=data["district"],
                defaults={
                    **data,
                    "city": "Abidjan",
                    "address": f"{data['commune']}, {data['district']}",
                    "images": DEMO_IMAGES,
                    "cover_image": DEMO_IMAGES[0],
                    "agent": agent,
                },
            )
            created_count += int(was_created)

        self.stdout.write(self.style.SUCCESS(f"{created_count} propriété(s) créée(s)."))

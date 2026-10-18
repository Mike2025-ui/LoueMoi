"""Sert les fichiers de MEDIA_ROOT en développement (voir urls.py, actif
uniquement si settings.DEBUG) — remplace django.views.static.serve pour
ajouter le support des requêtes HTTP partielles (Range), sans quoi la
lecture vidéo réseau échoue systématiquement.

Cause exacte du bug "vidéo publiée mais illisible" : ni
django.views.static.serve ni django.http.FileResponse ne gèrent le header
Range (vérifié en lisant leur code source — FileResponse.set_headers() ne
positionne que Content-Length/Content-Type/Content-Disposition, jamais
Accept-Ranges/Content-Range). Une vidéo réelle filmée par un téléphone place
presque toujours l'atome MP4 "moov" (métadonnées : pistes, durée, table des
échantillons) à la FIN du fichier plutôt qu'au début ("fast-start" est une
optimisation de post-traitement que les apps caméra n'appliquent pas par
défaut) — video_player (ExoPlayer côté Android) a donc besoin de sauter
directement à la fin du fichier via une requête Range avant de pouvoir
initialiser la lecture. Sans ce support, le serveur renvoie toujours 200 +
le fichier depuis le début, ExoPlayer ne peut pas localiser "moov",
l'initialisation échoue, et PropertyVideoPlayer bascule silencieusement sur
son état d'erreur (voir property_video_player.dart) — aucune exception
visible, aucun 4xx/5xx, juste une vidéo qui ne se lit jamais.
"""

import mimetypes
import re
from pathlib import Path

from django.http import HttpResponse, StreamingHttpResponse
from django.utils._os import safe_join
from django.views.static import serve as django_static_serve

_RANGE_RE = re.compile(r"bytes\s*=\s*(\d*)-(\d*)\s*$", re.IGNORECASE)
_CHUNK_SIZE = 64 * 1024


def _stream_range(fullpath, start, end):
    remaining = end - start + 1
    with open(fullpath, "rb") as handle:
        handle.seek(start)
        while remaining > 0:
            chunk = handle.read(min(_CHUNK_SIZE, remaining))
            if not chunk:
                break
            remaining -= len(chunk)
            yield chunk


def serve_media(request, path, document_root=None, show_indexes=False):
    """Délègue à la vue standard de Django pour tout (fichier introuvable,
    If-Modified-Since, Content-Type, listing de dossier...) — n'ajoute que
    la gestion d'un header Range à une seule plage, seul besoin réel de
    video_player. Une syntaxe Range absente, invalide, ou multi-plages
    (rarissime pour un lecteur vidéo) retombe simplement sur le
    comportement standard (200, fichier entier)."""
    # Sécurité : les pièces jointes de messagerie privées ne doivent jamais
    # être servies directement via MEDIA_URL — seul l'endpoint authentifié
    # MessageAttachmentDownloadView (/api/messages/{id}/attachment/) est autorisé.
    clean_path = path.lstrip("/\\")
    if clean_path.startswith("messages/") or clean_path.startswith("private_messages/"):
        return HttpResponse("Accès direct aux pièces jointes privé interdit.", status=403)

    range_header = request.META.get("HTTP_RANGE")
    if not range_header:
        response = django_static_serve(
            request, path, document_root=document_root, show_indexes=show_indexes
        )
        response.headers.setdefault("Accept-Ranges", "bytes")
        return response

    match = _RANGE_RE.match(range_header)
    if not match:
        response = django_static_serve(
            request, path, document_root=document_root, show_indexes=show_indexes
        )
        response.headers.setdefault("Accept-Ranges", "bytes")
        return response

    # Réutilise les mêmes vérifications que la vue standard (chemin sûr,
    # existence, pas un dossier) avant de servir une réponse partielle —
    # si le fichier n'existe pas, ceci lève Http404 exactement comme
    # django.views.static.serve.
    fullpath = Path(safe_join(document_root, path))
    if not fullpath.exists() or fullpath.is_dir():
        return django_static_serve(
            request, path, document_root=document_root, show_indexes=show_indexes
        )

    file_size = fullpath.stat().st_size
    start_str, end_str = match.groups()
    start = int(start_str) if start_str else 0
    end = int(end_str) if end_str else file_size - 1
    end = min(end, file_size - 1)

    if start > end or start >= file_size:
        response = HttpResponse(status=416)
        response.headers["Content-Range"] = f"bytes */{file_size}"
        return response

    content_type, _encoding = mimetypes.guess_type(str(fullpath))
    content_type = content_type or "application/octet-stream"

    response = StreamingHttpResponse(
        _stream_range(fullpath, start, end),
        status=206,
        content_type=content_type,
    )
    response.headers["Content-Length"] = str(end - start + 1)
    response.headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"
    response.headers["Accept-Ranges"] = "bytes"
    return response

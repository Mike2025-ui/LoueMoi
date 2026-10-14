"""Validation de la vidéo d'annonce (point 2 — vidéo dans les annonces).

Aucune bibliothèque de parsing vidéo n'est présente dans requirements.txt
(Pillow ne gère que l'image) — la durée est donc extraite en lisant
directement la boîte MP4/ISO-BMFF `moov/mvhd` (struct, stdlib uniquement),
plutôt que d'ajouter une dépendance. Best-effort : un conteneur atypique ne
lève jamais d'exception, la durée est simplement considérée inconnue et la
taille (MAX_VIDEO_SIZE_BYTES) reste la garde-fou principal.
"""

import os
import struct


def _iter_boxes(data, start, end):
    pos = start
    while pos + 8 <= end:
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        box_type = data[pos + 4:pos + 8].decode("latin-1", errors="ignore")
        header_size = 8
        if size == 1:
            if pos + 16 > end:
                return
            size = struct.unpack(">Q", data[pos + 8:pos + 16])[0]
            header_size = 16
        elif size == 0:
            size = end - pos
        if size < header_size:
            return
        yield box_type, pos + header_size, pos + size
        pos += size


def _parse_mvhd_duration(data):
    for box_type, content_start, content_end in _iter_boxes(data, 0, len(data)):
        if box_type != "moov":
            continue
        for inner_type, inner_start, inner_end in _iter_boxes(data, content_start, content_end):
            if inner_type != "mvhd":
                continue
            version = data[inner_start]
            if version == 1:
                if inner_start + 32 > inner_end:
                    return None
                timescale = struct.unpack(">I", data[inner_start + 20:inner_start + 24])[0]
                duration = struct.unpack(">Q", data[inner_start + 24:inner_start + 32])[0]
            else:
                if inner_start + 20 > inner_end:
                    return None
                timescale = struct.unpack(">I", data[inner_start + 12:inner_start + 16])[0]
                duration = struct.unpack(">I", data[inner_start + 16:inner_start + 20])[0]
            if timescale == 0:
                return None
            return duration / timescale
        return None
    return None


def get_mp4_duration_seconds(file_obj):
    """Durée en secondes, ou None si elle n'a pas pu être déterminée
    (conteneur non reconnu) — jamais d'exception propagée."""
    try:
        file_obj.seek(0)
        data = file_obj.read()
        file_obj.seek(0)
        return _parse_mvhd_duration(data)
    except Exception:
        return None


def validate_video_file(video_file, *, max_size_bytes, max_duration_seconds, allowed_extensions, allowed_content_types):
    errors = []

    if video_file.size > max_size_bytes:
        max_mo = max_size_bytes // (1024 * 1024)
        errors.append(f"La vidéo dépasse la taille maximale de {max_mo} Mo.")

    ext = os.path.splitext(video_file.name or "")[1].lower()
    content_type = (getattr(video_file, "content_type", "") or "").lower()
    if ext not in allowed_extensions and content_type not in allowed_content_types:
        errors.append("Format vidéo non pris en charge (MP4 uniquement).")

    # La durée n'est vérifiée que si taille/format sont déjà valides — inutile
    # de parser un fichier qu'on va de toute façon rejeter.
    if not errors:
        duration = get_mp4_duration_seconds(video_file)
        if duration is not None and duration > max_duration_seconds:
            errors.append(
                f"La vidéo dépasse la durée maximale de {max_duration_seconds} secondes."
            )

    return errors

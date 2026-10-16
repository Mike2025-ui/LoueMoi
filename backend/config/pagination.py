from rest_framework.pagination import PageNumberPagination


class DefaultPagination(PageNumberPagination):
    """?page=&page_size= — le client (ex: l'écran Favoris) peut demander une
    page plus large pour éviter de paginer une liste courte."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 500

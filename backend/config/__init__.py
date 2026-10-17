import django.urls
import django.urls.converters
import rest_framework.urlpatterns

_orig_register_converter = django.urls.converters.register_converter

def _safe_register_converter(converter, type_name):
    if type_name in django.urls.converters.REGISTERED_CONVERTERS or type_name in django.urls.converters.DEFAULT_CONVERTERS:
        return
    _orig_register_converter(converter, type_name)

django.urls.register_converter = _safe_register_converter
django.urls.converters.register_converter = _safe_register_converter
rest_framework.urlpatterns.register_converter = _safe_register_converter


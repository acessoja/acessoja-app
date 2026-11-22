from django import template
from django.contrib.admin.views.main import PAGE_VAR

register = template.Library()

STATE_LABELS = {
    "pending": "Pendente", "reviewing": "Em análise", "revision_requested": "Aguardando revisão",
    "closed": "Concluída", "approved": "Aprovada", "rejected": "Rejeitada",
}


@register.simple_tag
def moderation_filter_choices(changelist, spec):
    return list(spec.choices(changelist))


@register.simple_tag
def moderation_filter_title(spec):
    return {"state": "Estado", "created at": "Data de envio"}.get(str(spec.title), str(spec.title))


@register.filter
def moderation_state(value):
    return STATE_LABELS.get(value, value)


@register.inclusion_tag("admin/moderation/pagination.html")
def moderation_pagination(changelist, label="registros"):
    page = changelist.page_num
    total = changelist.paginator.num_pages
    return {
        "count": changelist.result_count,
        "label": label,
        "number": page,
        "total": total,
        "previous": changelist.get_query_string({PAGE_VAR: page - 1}) if page > 1 else None,
        "next": changelist.get_query_string({PAGE_VAR: page + 1}) if page < total else None,
    }

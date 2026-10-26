"""Resource evidence and predictable filters, independent of Django."""
from copy import deepcopy
from datetime import datetime

from acessoja.accessibility_catalog import LEGACY_FLAGS, RESOURCE_IDS, WRITE_STATES
from modal_avaliacao.questionnaire import summarize
from .services.categories import CATEGORIES


def validate_information(value):
    if not isinstance(value, dict):
        raise ValueError("Informações de acessibilidade devem ser um objeto por recurso.")
    clean = {}
    for key, entry in value.items():
        if key not in RESOURCE_IDS:
            raise ValueError("Recurso desconhecido.")
        if entry is None:
            clean[key] = None
            continue
        if not isinstance(entry, dict) or set(entry) - {"state", "note", "observed_at"}:
            raise ValueError("Cada recurso aceita state, note e observed_at; a origem é definida pelo servidor.")
        if not isinstance(entry.get("state"), str) or entry["state"] not in WRITE_STATES:
            raise ValueError("Estado inválido; use presence_reported, absence_reported ou unknown.")
        note = entry.get("note", "")
        if not isinstance(note, str) or len(note) > 1000:
            raise ValueError("A limitação deve ser texto com até 1000 caracteres.")
        observed = entry.get("observed_at")
        if observed is not None:
            if not isinstance(observed, str):
                raise ValueError("Data de observação inválida.")
            try:
                parsed = datetime.fromisoformat(observed.replace("Z", "+00:00"))
                if parsed.utcoffset() is None:
                    raise ValueError
                from django.utils import timezone
                if parsed > timezone.now():
                    raise ValueError
            except ValueError:
                raise ValueError("A observação deve ser uma data ISO-8601 com fuso horário.") from None
            observed = parsed.isoformat()
        clean[key] = {"state": entry["state"], "note": note, "observed_at": observed}
    return clean


def merge_information(previous, patch, received_at, source):
    result = deepcopy(previous) if isinstance(previous, dict) else {}
    for key, entry in patch.items():
        if entry is None:
            result.pop(key, None)
        else:
            result[key] = {**entry, "source": source, "received_at": received_at}
    return result


def combine_states(states):
    states = set(states)
    if "divergent" in states or {"presence_reported", "absence_reported"} <= states:
        return "divergent"
    if "presence_reported" in states:
        return "presence_reported"
    if "absence_reported" in states:
        return "absence_reported"
    if "limited" in states:
        return "limited"
    if "unknown" in states or "unconfirmed" in states:
        return "unknown"
    if "not_applicable" in states:
        return "not_applicable"
    return "unknown"


def osm_information(tags):
    """General wheelchair=yes is never evidence of a particular feature."""
    value = (tags or {}).get("toilets:wheelchair")
    state = {"yes": "presence_reported", "no": "absence_reported", "limited": "limited"}.get(value)
    return {"banheiro_acessivel": {"state": state, "source": "openstreetmap", "observed_at": None,
                                   "received_at": None, "tag": "toilets:wheelchair"}} if state else {}


def resolve_information(registered=None, rows=(), external=None):
    summary = summarize(rows)
    community = {item["id"]: item for item in summary["features"]}
    result = {}
    registered = registered if isinstance(registered, dict) else {}
    external = external if isinstance(external, dict) else {}
    for key in RESOURCE_IDS:
        feature = community.get(key)
        evidence = []
        entry = registered.get(key)
        if isinstance(entry, dict) and entry.get("state") in WRITE_STATES:
            evidence.append({"source": "not_recorded", "received_at": None, "observed_at": None,
                             **entry, "kind": "registration"})
        if feature and feature["respondents"]:
            evidence.append({"state": feature["state"], "kind": "community", "source": "acessoja_community",
                             "received_at": feature["latest_at"], "observed_at": None,
                             "counts": feature["counts"], "respondents": feature["respondents"]})
        if key in external:
            evidence.append({**external[key], "kind": "external"})
        result[key] = {
            "state": combine_states(item["state"] for item in evidence), "evidence": evidence,
            "community_state": feature["state"] if feature else "not_asked_in_version",
            "legacy_not_comparable": summary["legacy_not_comparable"],
        }
    return result


def csv_values(value, allowed, name):
    if not isinstance(value, str):
        raise ValueError(f"{name}: envie identificadores separados por vírgula.")
    items = value.split(",") if value else []
    if any(item not in allowed for item in items):
        raise ValueError(f"{name}: identificador inválido.")
    return list(dict.fromkeys(items))


def parse_filters(params):
    accepted = {"recursos", "categorias", "origens", "incluir_desconhecidos", "search", "format", *LEGACY_FLAGS}
    if set(params) - accepted:
        raise ValueError("Parâmetro de filtro desconhecido.")
    resources = csv_values(params.get("recursos", ""), RESOURCE_IDS, "recursos")
    for key in LEGACY_FLAGS:
        value = params.get(key)
        if value is not None and value not in ("true", "false"):
            raise ValueError(f"{key}: use true ou false.")
        if value == "true" and key not in resources:
            resources.append(key)
    incomplete = params.get("incluir_desconhecidos", "false")
    if incomplete not in ("true", "false"):
        raise ValueError("incluir_desconhecidos: use true ou false.")
    text = params.get("search", "")
    if not isinstance(text, str) or len(text) > 180:
        raise ValueError("Busca inválida ou muito longa.")
    return {"resources": resources, "categories": csv_values(params.get("categorias", ""), CATEGORIES, "categorias"),
            "sources": csv_values(params.get("origens", ""), ("acessoja", "openstreetmap"), "origens"),
            "include_unknown": incomplete == "true", "search": text}


def matching_resources(information, resources, include_unknown=False):
    missing = []
    for key in resources:
        state = information.get(key, {}).get("state", "unknown")
        if state == "presence_reported":
            continue
        if state == "unknown" and include_unknown:
            missing.append(key)
            continue
        return False, []
    return True, missing

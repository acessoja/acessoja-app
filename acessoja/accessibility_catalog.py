"""Shared resource vocabulary; questionnaire v2 retains its eight questions."""
from copy import deepcopy

CATALOG_VERSION = 1
RESOURCE_STATES = ("presence_reported", "absence_reported", "unknown", "divergent", "not_applicable", "limited")
WRITE_STATES = RESOURCE_STATES[:3]
LEGACY_FLAGS = ("cao_guia", "mesa_acessivel", "banheiro_acessivel", "rampa_acesso", "cardapio_braille")


def resource(code, group, pt, en, desc_pt, desc_en, question=None, osm=None):
    return {
        "id": code, "group": group, "name": {"pt": pt, "en": en},
        "description": {"pt": desc_pt, "en": desc_en}, "states": list(RESOURCE_STATES),
        "legacy_field": code if code in LEGACY_FLAGS else None,
        "questionnaire": {"version": 2, "question": code} if question else None,
        "osm_tag": osm,
    }


RESOURCES = [
    resource("rampa_acesso", "entrada", "Rampa na entrada", "Entrance ramp",
             "Rampa na entrada utilizada; não comprova dimensões ou inclinação conforme normas.",
             "Ramp at the entrance used; does not certify dimensions or slope.", True),
    resource("vagas_reservadas", "entrada", "Vagas reservadas", "Reserved parking spaces",
             "Vagas reservadas no estacionamento próprio, sem deduzir condições do entorno.",
             "Reserved spaces in on-site parking, without inferring nearby conditions.", True),
    resource("banheiro_acessivel", "espaco", "Banheiro com recursos de adaptação", "Restroom adaptation features",
             "Banheiro com recursos informados de adaptação; não é certificação técnica.",
             "Restroom with reported adaptation features; not technical certification.", True, "toilets:wheelchair"),
    resource("mesa_acessivel", "espaco", "Espaço sob mesas", "Knee space below tables",
             "Espaço inferior para aproximação de cadeira de rodas; não significa estacionamento reservado.",
             "Knee space for wheelchair approach; does not mean reserved parking.", True),
    resource("cardapio_braille", "comunicacao", "Cardápio em Braille", "Braille menu",
             "Oferta de cardápio em Braille; não deduz outros formatos de comunicação.",
             "Availability of a Braille menu; no inference about other communication formats.", True),
    resource("atendimento_libras", "comunicacao", "Atendimento em Libras", "Service in Libras",
             "Atendimento informado em Libras. Consulte o local sobre horários e disponibilidade; "
             "não é garantia permanente.",
             "Reported service in Brazilian Sign Language. Ask about hours and availability; "
             "not a permanent guarantee.",
             True),
    resource("sinalizacao_tatil", "orientacao", "Sinalização tátil", "Tactile signage",
             "Sinais em relevo ou Braille para orientação; não equivale a piso tátil contínuo.",
             "Raised or Braille signs for orientation; not equivalent to continuous tactile paving.", True),
    resource("cao_guia", "orientacao", "Acolhimento de pessoas com cão-guia", "Service for people with guide dogs",
             "Acolhimento informado pelo atendimento; não significa ausência de obstáculos.",
             "Reported welcome by the service; does not mean an obstacle-free environment.", True),
    resource("piso_tatil", "orientacao", "Piso tátil", "Tactile paving",
             "Faixas de piso com relevo para orientação ou alerta no local. Não comprova continuidade ou conformidade.",
             "Textured paving for orientation or warning at the place. Does not certify continuity or compliance."),
    resource("sinalizacao_visual", "orientacao", "Sinalização visual legível", "Legible visual signage",
             "Sinais de orientação visual com texto ou pictogramas legíveis. Não representa acessibilidade para todos.",
             "Visual orientation signs with legible text or pictograms. "
             "Does not represent accessibility for everyone."),
]
RESOURCE_IDS = tuple(item["id"] for item in RESOURCES)
RESOURCE_NAMES = {item["id"]: item["name"] for item in RESOURCES}


def catalog():
    return deepcopy({"version": CATALOG_VERSION, "resources": RESOURCES, "states": list(RESOURCE_STATES)})


def validate_preferences(value):
    if not isinstance(value, list) or len(value) > 100:
        raise ValueError("Envie uma lista de identificadores de recursos (até 100 itens antes da deduplicação).")
    if any(not isinstance(item, str) or item not in RESOURCE_IDS for item in value):
        raise ValueError("Há recursos desconhecidos ou descontinuados. Revise a seleção explicitamente.")
    return [key for key in RESOURCE_IDS if key in value]

"""Versioned vocabulary. Legacy answers never imply a current feature."""
from copy import deepcopy

VERSION = 2
ANSWER_CODES = ("yes", "no", "unknown", "not_applicable")
LEGACY_VALUES = ("Sim", "Não", "Não sei", "Não se aplica")
ANSWER_LABELS = {
    "yes": {"pt": "Sim", "en": "Yes"},
    "no": {"pt": "Não", "en": "No"},
    "unknown": {"pt": "Não sei", "en": "I don't know"},
    "not_applicable": {"pt": "Não se aplica", "en": "Not applicable"},
}
LEGACY_QUESTIONS = [
    "Existem rampas de acesso na entrada do local?",
    "Esse lugar tem banheiro acessível?",
    "Há vagas de estacionamento reservadas para pessoas com deficiência?",
    "O ambiente é livre de barreiras e obstáculos que dificultem a locomoção?",
]
RESOURCE_NAMES = {
    "rampa_acesso": {"pt": "Rampa na entrada", "en": "Entrance ramp"},
    "vagas_reservadas": {"pt": "Vagas reservadas", "en": "Reserved parking spaces"},
    "banheiro_acessivel": {"pt": "Banheiro com recursos de adaptação", "en": "Restroom adaptation features"},
    "mesa_acessivel": {"pt": "Espaço sob mesas", "en": "Knee space below tables"},
    "cardapio_braille": {"pt": "Cardápio em Braille", "en": "Braille menu"},
    "atendimento_libras": {"pt": "Atendimento em Libras", "en": "Service in Libras"},
    "sinalizacao_tatil": {"pt": "Sinalização tátil", "en": "Tactile signage"},
    "cao_guia": {"pt": "Acolhimento de pessoas com cão-guia", "en": "Service for people with guide dogs"},
}


def question(code, group, pt, en, description_pt, description_en, na_pt, na_en):
    return {
        "id": code, "resource": code, "group": group, "required": True, "version": VERSION,
        "name": RESOURCE_NAMES[code],
        "text": {"pt": pt, "en": en}, "description": {"pt": description_pt, "en": description_en},
        "not_applicable": {"pt": na_pt, "en": na_en},
    }


QUESTIONS = [
    question("rampa_acesso", "entrada", "Existe rampa na entrada?", "Is there an entrance ramp?",
             "Observe a entrada utilizada.", "Observe the entrance used.",
             "Entrada sem desnível que exija rampa.", "An entrance without a level change requiring a ramp."),
    question("vagas_reservadas", "entrada", "Há vagas reservadas no estacionamento do local?",
             "Are there reserved spaces in the place's parking area?",
             "Considere o estacionamento próprio.", "Consider the place's own parking area.",
             "O local não tem estacionamento próprio; isso não informa sobre o entorno.",
             "There is no on-site parking; this says nothing about nearby parking."),
    question("banheiro_acessivel", "espaco", "Há banheiro com recursos de adaptação?",
             "Is there a restroom with adaptation features?",
             "Relate o que observou, sem certificar normas.", "Report what you observed without certifying standards.",
             "O local não oferece banheiro ao público.", "The place provides no public restroom."),
    question("mesa_acessivel", "espaco", "Há mesas com espaço inferior para aproximação de cadeira de rodas?",
             "Are there tables with knee space for wheelchair approach?",
             "Observe o espaço livre sob a mesa; não é necessária medição.",
             "Observe the clear space below the table; no measurement is required.",
             "O serviço não utiliza mesas para o público.", "The service provides no tables for visitors."),
    question("cardapio_braille", "comunicacao", "Existe cardápio em Braille?", "Is there a Braille menu?",
             "Pergunte ou observe se o recurso é oferecido.", "Ask or observe whether this feature is offered.",
             "O local não utiliza cardápio.", "The place does not use a menu."),
    question("atendimento_libras", "comunicacao", "Há atendimento em Libras?",
             "Is service available in Brazilian Sign Language (Libras)?",
             "Considere o atendimento informado ou observado.", "Consider service reported or observed.",
             "Não há serviço de atendimento neste local.", "No visitor assistance service exists at this place."),
    question("sinalizacao_tatil", "orientacao", "Há sinalização tátil para orientação?",
             "Is there tactile signage for orientation?",
             "Considere sinais táteis observados, sem deduzir continuidade.",
             "Consider observed tactile signs without inferring continuity.",
             "A situação observada não utiliza sinalização para orientação.",
             "The observed situation does not use orientation signage."),
    question("cao_guia", "orientacao", "O atendimento aceita pessoas acompanhadas de cão-guia?",
             "Does the service welcome people accompanied by guide dogs?",
             "Relate informação do atendimento, não a ausência de obstáculos.",
             "Report service information, not the absence of obstacles.",
             "Não há serviço de atendimento neste local.", "No visitor assistance service exists at this place."),
]
QUESTION_IDS = tuple(q["id"] for q in QUESTIONS)
GROUPS = {
    "entrada": {"pt": "Entrada e estacionamento", "en": "Entrance and parking"},
    "espaco": {"pt": "Uso do espaço", "en": "Use of the space"},
    "comunicacao": {"pt": "Comunicação", "en": "Communication"},
    "orientacao": {"pt": "Orientação e acolhimento", "en": "Orientation and assistance"},
}


def catalog():
    return deepcopy({
        "version": VERSION, "answers": ANSWER_LABELS, "groups": GROUPS, "questions": QUESTIONS,
        "legacy": {"version": 1, "comparable": False, "meaning": "unversioned"},
    })


def validate_answers(value):
    if not isinstance(value, dict):
        raise ValueError("Respostas devem ser um objeto de recurso para código.")
    for key, answer in value.items():
        if key not in QUESTION_IDS:
            raise ValueError("Recurso fora do contrato.")
        if answer is not None and (not isinstance(answer, str) or answer not in ANSWER_CODES):
            raise ValueError("Código de resposta inválido.")
    return value


def complete(version, answers, legacy=()):
    if version == VERSION:
        return isinstance(answers, dict) and all(answers.get(key) in ANSWER_CODES for key in QUESTION_IDS)
    return version == 1 and len(legacy) == 4 and all(value in LEGACY_VALUES for value in legacy)


def summarize(rows):
    """One current valid response per author; all four votes remain visible."""
    features = {
        key: {"id": key, "counts": dict.fromkeys(ANSWER_CODES, 0), "unanswered": 0, "latest_at": None}
        for key in QUESTION_IDS
    }
    seen = set()
    legacy = invalid = people = duplicate = 0
    for row in rows:
        if not row.get("is_current", True):
            continue
        author = row["user_id"]
        if author in seen:
            duplicate += 1
            continue
        seen.add(author)
        if not row.get("is_valid", True):
            invalid += 1
            continue
        people += 1
        if row.get("questionnaire_version", 1) != VERSION:
            legacy += 1
            continue
        answers = row.get("answers") or {}
        dates = row.get("answer_dates") or {}
        for key, feature in features.items():
            answer = answers.get(key)
            if answer not in ANSWER_CODES:
                feature["unanswered"] += 1
                continue
            feature["counts"][answer] += 1
            received = dates.get(key)
            if received and (feature["latest_at"] is None or received > feature["latest_at"]):
                feature["latest_at"] = received
    for feature in features.values():
        counts = feature["counts"]
        yes, no, unknown, na = (counts[key] for key in ANSWER_CODES)
        feature["state"] = (
            "divergent" if yes and no else "presence_reported" if yes else "absence_reported" if no
            else "unconfirmed" if unknown else "not_applicable" if na else "not_evaluated"
        )
        feature["respondents"] = sum(counts.values())
        feature["few_reviews"] = 0 < feature["respondents"] < 3
        feature["legacy_not_comparable"] = legacy
    return {
        "version": VERSION, "people": people, "legacy_not_comparable": legacy,
        "excluded_invalid": invalid, "duplicates_excluded": duplicate, "features": list(features.values()),
        "date_kind": "answer_received_at",
    }

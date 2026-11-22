"""Declarative v3 vocabulary shared by the API and the generated Flutter snapshot.

IDs are features, not diagnoses. Missing characteristics never imply a service.
Scales describe observations and never create permanent positive evidence.
"""
from copy import deepcopy

DIMENSIONS = {
    "physical": {"pt": "Mobilidade física", "en": "Physical mobility"},
    "visual": {"pt": "Acessibilidade visual", "en": "Visual accessibility"},
    "hearing": {"pt": "Acessibilidade auditiva", "en": "Hearing accessibility"},
    "sensory": {"pt": "Ambiente sensorial", "en": "Sensory environment"},
    "cognitive": {"pt": "Orientação e compreensão", "en": "Orientation and understanding"},
    "communication": {"pt": "Comunicação e atendimento", "en": "Communication and assistance"},
}
PRESENCE = ("yes", "no", "unknown", "not_applicable")
SCALE = ("low", "moderate", "high", "unknown", "not_applicable")
SCALE_IDS = {"ruido_ambiente", "iluminacao_intensa", "aglomeracao_observada"}
CHARACTERISTICS = {
    "parking": {"pt": "Existe estacionamento próprio?", "en": "Is there on-site parking?"},
    "restroom": {"pt": "Há banheiro para visitantes?", "en": "Is there a visitor restroom?"},
    "levels": {"pt": "Há circulação entre andares?", "en": "Do visitors move between floors?"},
    "menu": {"pt": "O serviço utiliza cardápio?", "en": "Does the service use a menu?"},
    "waiting": {"pt": "Existe espaço de espera?", "en": "Is there a waiting area?"},
    "calls": {"pt": "O serviço utiliza chamadas ou senhas?", "en": "Does the service use calls or tickets?"},
    "self_service": {"pt": "Existe autoatendimento?", "en": "Is self-service available?"},
}

# id, dimension, concise feature label, observable question (PT and EN).
DEFINITIONS = [
    ("rampa_acesso", "physical", "Rampa na entrada", "Entrance ramp", "Existe rampa na entrada utilizada?", "Is there a ramp at the entrance used?"),
    ("vagas_reservadas", "physical", "Vagas reservadas", "Reserved parking", "Há vagas reservadas no estacionamento próprio?", "Are there reserved spaces in the on-site parking?"),
    ("banheiro_acessivel", "physical", "Banheiro com adaptações", "Restroom adaptations", "Há banheiro com recursos de adaptação?", "Does the restroom have adaptation features?"),
    ("mesa_acessivel", "physical", "Espaço sob mesas", "Knee space below tables", "Há espaço sob mesas para aproximação de cadeira de rodas?", "Is there knee space for wheelchair approach?"),
    ("entrada_sem_degraus", "physical", "Entrada sem degraus", "Step-free entrance", "Existe entrada sem degraus disponível aos visitantes?", "Is a step-free entrance available to visitors?"),
    ("circulacao_sem_obstaculos", "physical", "Circulação sem obstáculos", "Clear circulation", "Os caminhos internos estão livres de obstáculos?", "Are indoor paths free of obstacles?"),
    ("elevador_acessivel", "physical", "Elevador acessível", "Accessible lift", "O elevador permite acesso e uso por pessoa em cadeira de rodas?", "Can a wheelchair user access and use the lift?"),
    ("sinalizacao_tatil", "visual", "Sinalização tátil", "Tactile signage", "Há sinais em relevo ou Braille para orientação?", "Are there raised or Braille orientation signs?"),
    ("piso_tatil", "visual", "Piso tátil", "Tactile paving", "Há piso tátil para orientação ou alerta?", "Is there tactile paving for orientation or warning?"),
    ("cardapio_braille", "visual", "Cardápio em Braille", "Braille menu", "Existe cardápio em Braille?", "Is there a Braille menu?"),
    ("sinalizacao_visual", "visual", "Sinalização legível", "Legible signage", "Os sinais têm texto legível e contraste adequado?", "Do signs have legible text and adequate contrast?"),
    ("conteudo_leitor_tela", "visual", "Conteúdo para leitor de tela", "Screen reader content", "As informações digitais funcionam com leitor de tela?", "Does digital information work with a screen reader?"),
    ("informacao_sonora", "visual", "Informação sonora", "Audio information", "As informações de orientação também estão disponíveis em áudio?", "Is orientation information also available as audio?"),
    ("atendimento_libras", "hearing", "Atendimento em Libras", "Service in Libras", "Há atendimento em Libras? Informe disponibilidade se souber.", "Is service in Brazilian Sign Language available? Add availability if known."),
    ("atendimento_texto", "hearing", "Atendimento por texto", "Text assistance", "É possível receber atendimento por escrito?", "Is written assistance available?"),
    ("chamadas_visuais", "hearing", "Chamadas visuais", "Visual calls", "As chamadas ou senhas são exibidas visualmente?", "Are calls or tickets displayed visually?"),
    ("legendas", "hearing", "Legendas", "Captions", "O conteúdo audiovisual oferece legendas?", "Does audiovisual content offer captions?"),
    ("alertas_visuais", "hearing", "Alertas visuais", "Visual alerts", "Há alertas visuais complementando avisos sonoros?", "Are audio alerts complemented by visual alerts?"),
    ("espaco_tranquilo", "sensory", "Espaço tranquilo", "Quiet space", "Existe uma área alternativa com menor nível de ruído?", "Is there an alternative area with less noise?"),
    ("ruido_ambiente", "sensory", "Ruído observado", "Observed noise", "Como estava o barulho durante sua visita?", "How noisy was it during your visit?"),
    ("iluminacao_intensa", "sensory", "Intensidade da iluminação", "Lighting intensity", "Como estava a intensidade da luz? Relate luzes piscantes na observação.", "How intense was the lighting? Describe flashing lights in the note."),
    ("aglomeracao_observada", "sensory", "Aglomeração observada", "Observed crowding", "Como estava a quantidade de pessoas no ambiente?", "How crowded was the environment?"),
    ("horarios_menor_estimulo", "sensory", "Horários de menor estímulo", "Lower-stimulation hours", "O local informa períodos com menor estímulo sensorial?", "Does the place offer information about lower-stimulation hours?"),
    ("espera_tranquila", "sensory", "Espera tranquila", "Quiet waiting", "É possível aguardar em um ambiente mais tranquilo?", "Can visitors wait in a quieter environment?"),
    ("linguagem_simples", "cognitive", "Linguagem simples", "Plain language", "As instruções usam linguagem clara e simples?", "Do instructions use clear, plain language?"),
    ("pictogramas_orientacao", "cognitive", "Pictogramas", "Pictograms", "Há pictogramas para ajudar na orientação?", "Are pictograms available to help with orientation?"),
    ("sinalizacao_intuitiva", "cognitive", "Setores identificáveis", "Identifiable areas", "É fácil identificar os setores e caminhos pela sinalização?", "Do signs make areas and paths easy to identify?"),
    ("informacoes_antecipadas", "cognitive", "Informações antecipadas", "Advance information", "É possível conhecer o atendimento e o ambiente antes da visita?", "Can visitors learn about the service and environment before visiting?"),
    ("orientacao_assistida", "cognitive", "Orientação assistida", "Assisted orientation", "É possível solicitar ajuda para se orientar?", "Can visitors request help with orientation?"),
    ("cao_guia", "communication", "Acolhimento com cão-guia", "Welcome with a guide dog", "O atendimento acolhe pessoas acompanhadas de cão-guia?", "Does the service welcome people accompanied by guide dogs?"),
    ("atendimento_adaptavel", "communication", "Atendimento adaptável", "Adaptable assistance", "O atendimento permite ajustar ritmo ou forma de comunicação?", "Can the pace or form of communication be adjusted?"),
    ("comunicacao_alternativa", "communication", "Comunicação alternativa", "Alternative communication", "É possível usar imagens, escrita ou outros meios para se comunicar?", "Can visitors communicate using pictures, writing or other means?"),
    ("apoio_solicitavel", "communication", "Apoio mediante solicitação", "Assistance on request", "É possível solicitar apoio durante o atendimento?", "Can visitors request assistance during service?"),
    ("atendimento_assistido", "communication", "Atendimento assistido", "Assisted service", "Há alguém disponível para auxiliar no uso do serviço?", "Is someone available to help visitors use the service?"),
    ("informacoes_acessiveis", "communication", "Informações em outros formatos", "Information in alternative formats", "O atendimento oferece informações em formatos alternativos?", "Does the service offer information in alternative formats?"),
    ("cardapio_digital_acessivel", "visual", "Cardápio digital acessível", "Accessible digital menu", "O cardápio digital funciona com leitor de tela?", "Does the digital menu work with a screen reader?"),
    ("balcao_acessivel", "physical", "Balcão acessível", "Accessible counter", "Há trecho de balcão que permita aproximação e atendimento sentado?", "Is part of the counter usable from a seated position?"),
    ("caminhos_parque_acessiveis", "physical", "Caminhos transitáveis", "Usable park paths", "Os caminhos têm piso firme e passagem sem obstáculos?", "Do paths have a firm surface and clear passage?"),
    ("descanso_parque_acessivel", "physical", "Áreas de descanso", "Rest areas", "Existem áreas de descanso alcançáveis pelos caminhos?", "Are rest areas reachable from the paths?"),
    ("lazer_adaptado", "physical", "Lazer adaptado", "Adapted leisure", "Há equipamentos ou atividades de lazer adaptados?", "Are adapted leisure facilities or activities available?"),
    ("quarto_adaptado", "physical", "Quarto adaptado", "Adapted room", "Há quarto com espaço de circulação e recursos de adaptação?", "Is there a room with circulation space and adaptation features?"),
    ("banheiro_quarto_adaptado", "physical", "Banheiro do quarto adaptado", "Adapted room bathroom", "O quarto adaptado tem banheiro com recursos de adaptação?", "Does the adapted room have a bathroom with adaptation features?"),
    ("chamadas_sonoras", "visual", "Chamadas sonoras", "Audio calls", "As chamadas ou senhas também são anunciadas por áudio?", "Are calls or tickets also announced by audio?"),
    ("assentos_acessiveis", "physical", "Assentos e espaços acessíveis", "Accessible seating and spaces", "Há assentos e espaços reservados com acesso sem barreiras?", "Are there reserved seats and spaces with barrier-free access?"),
    ("audiodescricao", "visual", "Audiodescrição", "Audio description", "Há sessões ou conteúdos com audiodescrição?", "Are sessions or content with audio description available?"),
    ("autoatendimento_acessivel", "communication", "Autoatendimento acessível", "Accessible self-service", "O autoatendimento oferece recursos acessíveis e alternativa assistida?", "Does self-service offer accessible features and an assisted alternative?"),
    ("materiais_formatos_acessiveis", "visual", "Materiais acessíveis", "Accessible materials", "Há materiais em formatos como áudio, Braille ou texto digital acessível?", "Are materials available as audio, Braille or accessible digital text?"),
]
FOOD = ["restaurante", "lanchonete", "cafeteria"]
PARK = ["parque", "praca"]
HOTEL = ["hotel", "pousada", "hospedagem"]
HEALTH = ["saude", "hospital", "clinica", "consultorio"]
CULTURE = ["cultura", "cinema", "teatro"]
EDUCATION = ["educacao", "escola", "universidade", "biblioteca"]
APPLICABILITY = {
    "cardapio_braille": FOOD, "cardapio_digital_acessivel": FOOD,
    "mesa_acessivel": FOOD + EDUCATION + ["shopping"],
    "caminhos_parque_acessiveis": PARK, "descanso_parque_acessivel": PARK,
    "lazer_adaptado": PARK + ["academia", "esporte"],
    "quarto_adaptado": HOTEL, "banheiro_quarto_adaptado": HOTEL,
    "audiodescricao": CULTURE, "legendas": CULTURE + EDUCATION,
    "assentos_acessiveis": CULTURE + HEALTH + EDUCATION,
    "materiais_formatos_acessiveis": EDUCATION,
}
CONDITIONS = {
    "vagas_reservadas": "parking", "banheiro_acessivel": "restroom",
    "elevador_acessivel": "levels", "cardapio_braille": "menu",
    "cardapio_digital_acessivel": "menu", "espera_tranquila": "waiting",
    "chamadas_visuais": "calls", "chamadas_sonoras": "calls",
    "autoatendimento_acessivel": "self_service",
}
PRIMARY = ["entrada_sem_degraus", "espaco_tranquilo", "sinalizacao_visual", "atendimento_texto",
           "linguagem_simples", "comunicacao_alternativa", "ruido_ambiente", "circulacao_sem_obstaculos"]
QUESTIONS = [
    {"id": code, "resource": code, "dimension": dimension, "group": dimension,
     "name": {"pt": pt, "en": en}, "text": {"pt": question_pt, "en": question_en},
     "description": {"pt": "Relate apenas o que observou. Não é certificação técnica.",
                     "en": "Report only what you observed. This is not technical certification."},
     "version": 3, "required": False, "answer_type": "intensity" if code in SCALE_IDS else "presence",
     "answers": list(SCALE if code in SCALE_IDS else PRESENCE), "categories": APPLICABILITY.get(code, []),
     "condition": CONDITIONS.get(code), "variable": code in SCALE_IDS,
     "primary": code in PRIMARY, "filterable": code not in SCALE_IDS}
    for code, dimension, pt, en, question_pt, question_en in DEFINITIONS
]
BY_ID = {q["id"]: q for q in QUESTIONS}


def applicable(category=None, subcategory=None, characteristics=None):
    known = characteristics or {}
    categories = {category, subcategory} - {None, "", "outro"}
    return [q for q in QUESTIONS if (not q["categories"] or categories.intersection(q["categories"]))
            and (q["condition"] is None or known.get(q["condition"]) is True)]


def catalog(category=None, subcategory=None, characteristics=None):
    return deepcopy({"version": 3, "catalog_version": 3, "dimensions": DIMENSIONS,
                     "characteristics": CHARACTERISTICS,
                     "questions": applicable(category, subcategory, characteristics)})


def validate_answers(answers):
    if not isinstance(answers, dict):
        raise ValueError("Respostas devem ser um objeto de recurso para código.")
    for key, value in answers.items():
        if key not in BY_ID or value is not None and value not in BY_ID[key]["answers"]:
            raise ValueError("Recurso ou resposta fora do contrato v3.")
    return answers


def evidence_state(resource, value):
    if resource in SCALE_IDS:
        # A low stimulus report is contextual, never proof of a permanent feature.
        return {"low": "unknown", "moderate": "unknown", "high": "limited",
                "unknown": "unknown", "not_applicable": "not_applicable"}[value]
    return {"yes": "presence_reported", "no": "absence_reported", "unknown": "unknown",
            "not_applicable": "not_applicable"}[value]

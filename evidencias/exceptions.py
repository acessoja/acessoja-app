from rest_framework.exceptions import APIException


class RevisionConflict(APIException):
    status_code = 409
    default_detail = "A informação mudou. Atualize a tela e confira novamente antes de enviar."
    default_code = "revision_conflict"

from rest_framework.exceptions import APIException


class ImageRejected(APIException):
    status_code = 422
    default_detail = (
        "Imagem inválida, formato não suportado ou dimensões excedidas. Use JPEG, PNG ou WebP estático."
    )
    default_code = "image_rejected"


class ImageTooLarge(APIException):
    status_code = 413
    default_detail = "Cada arquivo pode ter até 5 MiB; a requisição completa pode ter até 6 MB."
    default_code = "image_too_large"


class ImageUnavailable(APIException):
    status_code = 503
    default_detail = (
        "Não foi possível confirmar a gravação da imagem. Consulte a operação antes de tentar novamente."
    )
    default_code = "image_unavailable"

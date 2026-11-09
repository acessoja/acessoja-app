# Processamento de imagens

O processamento usa o Pillow instalado no mesmo Python do backend. O subprocesso `midia.image_worker` é iniciado com `sys.executable`; portanto, iniciar o Django com outro Python pode produzir um ambiente diferente do validado.

Antes de homologar upload, execute com o Python da `.venv`:

```powershell
.\.venv\Scripts\python.exe -c "from PIL import Image, ImageOps; from PIL import _imaging; print(Image.__version__)"
.\.venv\Scripts\python.exe -m pytest midia/test_images.py -q
```

Um import que falha, inclusive `PIL._imaging`, indica instalação incompleta ou incompatível do Pillow. Verifique o interpretador usado pelo servidor e seu ambiente virtual antes de alterar o contrato de upload.

O worker retorna código 2 para imagem recusada e código 3 quando o import do processador falha. O backend responde com erro de validação somente no primeiro caso; o segundo é indisponibilidade temporária. Os logs registram apenas a classe do problema, sem nomes de arquivos, conteúdo privado ou caminhos temporários.

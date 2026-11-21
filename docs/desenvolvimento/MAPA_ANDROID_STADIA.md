# Mapa Stadia no Android físico

O aplicativo usa tiles raster Stadia `alidade_smooth` no tema claro e
`alidade_smooth_dark` no escuro. No Android, a integração exige uma chave de
aplicação nativa da propriedade Stadia. Sem `STADIA_API_KEY`, o aplicativo
mantém marcadores e controles e informa que a cartografia não está configurada.
A chave não deve ser gravada no repositório nem colocada na URL dos tiles.

Para homologar, o responsável deve conferir no painel Stadia a propriedade,
plano, cota e autorização de uso, então iniciar o build com uma chave **de
cliente** fora do Git:

```powershell
flutter run -d <ID_DO_ANDROID> `
  --dart-define=API_BASE_URL=http://<IP_DA_MAQUINA>:8000 `
  --dart-define=STADIA_MAPS_ENABLED=true `
  --dart-define=STADIA_API_KEY=<CHAVE_DE_CLIENTE>
```

`API_BASE_URL` precisa ser alcançável pelo telefone. O valor padrão
`10.0.2.2` serve para emulador, não para Android físico. Verifique o status
das requisições de tiles em uma sessão real: 401 indica autenticação inválida,
403 pode indicar permissão/plano, 429 indica limite e falhas de transporte
podem indicar rede. O app mantém aviso e ação de tentar novamente. O aviso
fica sobre o mapa e não reduz sua área.

Confirme visualmente os dois temas, atribuições Stadia/OpenMapTiles/OSM,
marcadores, agrupamentos, busca, filtros, rota, geolocalização, telas pequenas
e texto ampliado. Testes com provedor simulado e um build sem chave não
comprovam o carregamento da cartografia real.

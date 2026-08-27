# WebHider 1.0

Tweak genérico para WebFrame/WebKit voltado à inspeção e ocultação de elementos de páginas.

## Protocolo Hider

A versão 1.0 usa selectors CSS estáveis ao salvar elementos ocultados, evitando depender de caminhos estruturais frágeis com `nth-of-type(...)` quando existe um identificador estável disponível.

O filtro mantém o formato compatível com o WebFrame:

```json
{
  "action": {
    "type": "css-display-none",
    "selector": ".q-page-sticky"
  },
  "trigger": {
    "url-filter": ".*"
  }
}
```

Elementos compostos podem gerar mais de uma regra de ocultação; isso é intencional quando necessário para alcançar o resultado visual completo.

## Recursos

- Ativação por gesto de três toques.
- Inspector de elementos Web.
- Visualização da hierarquia DOM.
- Ocultar e salvar elementos.
- Persistência em `custom-filters.json`.
- Tela de elementos ocultos.
- Reativação individual ou de todos os filtros.
- Aplicação dos filtros em todas as páginas WebView conhecidas.

## Escopo

O WebHider permanece genérico e não é amarrado ao Bundle Identifier de um aplicativo específico.

A base funcional desta versão é a V21 validada no aparelho. O nome comercial do tweak é **WebHider 1.0**; os prefixos internos `PH` foram preservados para evitar alterações desnecessárias na implementação já validada.

## Artefato

O GitHub Actions publica `WebHider-1.0.dylib`, destinado ao fluxo de injeção direta na IPA.

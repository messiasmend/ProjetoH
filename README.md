# ProjetoH

## V2 — Reference-style activation foundation

Esta versão reconstrói a fundação do ProjetoH a partir do fluxo observado na `LocationSpoofer-v2.dylib`, sem copiar o código da referência.

### Fluxo de ativação

```text
Dylib carregada
      |
      v
Inicialização do ProjetoH
      |
      v
UIApplication / UIWindow
      |
      v
sendEvent:
      |
      v
PHThreeFingerGesture
      |
      +-- 3 toques qualificantes?
      |       |
      |       +-- não -> cancela timer / reseta estado
      |       |
      |       +-- sim -> arma NSTimer de 0,8 s
      |
      v
trigger confirmado
      |
      v
PHOverlayManager
      |
      v
Inspector apresentado como modal overlay
```

### V2 changes

- Hook direto de `UIApplication -sendEvent:`.
- Hook adicional de `UIWindow -sendEvent:` quando a classe expõe o seletor.
- O evento original é executado antes da análise, como na referência.
- O detector trabalha diretamente sobre `UIEvent.allTouches`.
- O gesto usa 3 toques e hold de 0,8 s.
- Timer executado na main run loop.
- Estado de timer/trigger separado para evitar disparos repetidos.
- GUI apresentada pelo `PHOverlayManager` sobre o controlador de topo, em vez de depender de uma janela independente.
- Workflow valida que o artefato publicado é um Mach-O `DYLIB` real; arquivos dSYM não são aceitos como artefato.

### Artefato

O GitHub Actions publica:

`ProjetoH-V2.dylib`

O artefato é destinado ao fluxo de injeção direta na IPA. O pacote `.deb` continua sendo apenas uma saída auxiliar do build Theos.

### Escopo

O ProjetoH permanece genérico e não é amarrado a Bundle Identifier específico. A `LocationSpoofer-v2.dylib` é usada somente como referência técnica de comportamento e arquitetura; o código do ProjetoH é uma implementação própria.

O Inspector de Elementos será construído sobre esta fundação depois que a ativação e a apresentação da GUI forem validadas no aparelho.

<!-- ProjetoH V9 one-shot fix trigger -->

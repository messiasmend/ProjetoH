# ProjetoH

V1 — Fundação do Inspector de Elementos.

## Objetivo desta versão

A primeira versão valida apenas a infraestrutura que será usada pelo Inspector:

1. Hook genérico de `UIApplication -sendEvent:`.
2. Processamento do `UIEvent` depois do evento original.
3. Detecção de três toques qualificantes.
4. Hold de 0,8 segundo com `NSTimer` na main run loop.
5. Estado para impedir múltiplos disparos simultâneos.
6. Overlay independente com uma GUI de teste.

## Arquitetura

```text
UIApplication/sendEvent:
        |
        v
PHThreeFingerGesture
        |
        +-- 3 toques?
        |      |
        |      +-- não -> cancela timer
        |      |
        |      +-- sim -> arma 0,8 s
        |
        v
PHOverlayManager
        |
        v
PHOverlayWindow / GUI de teste
```

## Escopo

Esta base é genérica e não contém filtro por Bundle Identifier. O Inspector de Elementos será adicionado em uma etapa posterior, depois de validarmos a ativação e o overlay.

A `LocationSpoofer-v2.dylib` é tratada somente como referência técnica para o fluxo de eventos, estado do gesto, temporização e arquitetura de overlay. O código do ProjetoH é uma implementação própria.

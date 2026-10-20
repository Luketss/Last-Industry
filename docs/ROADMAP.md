# Roteiro por fases

Cada fase termina com um build executável (CI: artefatos Windows e Linux), critérios de conclusão
verificáveis e testes automatizados.

| Fase | Escopo | Estado |
|---|---|---|
| 1 | Construir e remover estruturas | ✅ Concluída |
| 2 | Mineração, transporte e processamento | ✅ Concluída |
| 3 | Energia e fabricação de munição | ✅ Concluída |
| 4 | Torres, muros, inimigos e combate | ✅ Concluída |
| 5 | Integração produção ↔ defesa | ✅ Concluída |
| 6 | Pesquisa, objetivos e progressão | ✅ Concluída |
| 7 | Otimização, interface e experiência | ✅ Concluída (remapeamento de teclas e localização ficam para a Fase 8) |
| 8 | Builds de teste e distribuição Steam | ✅ Pipeline, conquistas, integração Steam opcional e remapeamento prontos. Dependem da sua conta: App ID, depots e segredos (ver STEAM.md) |

## Critérios de conclusão e testes

### Fase 1 — Construção
- Posicionar com validação (limites, sobreposição, ruínas, jazida, ninho, custo), girar, remover com reembolso.
- Testes: `test_construction.gd` (5 testes).

### Fase 2 — Mineração, transporte, processamento
- Mineradora → esteiras → fundição → núcleo sem intervenção. Divisor distribui. Estados de gargalo visíveis.
- Testes: `test_logistics.gd` (`test_miner_belt_core`, `test_smelter_chain_and_stats`, `test_splitter_distributes`, ...).

### Fase 3 — Energia e munição
- Redes por postes, máquinas sem conexão param, prioridade defesa > produção, gerador queima carvão, baterias.
- Montadora produz munição de placa + carvão.
- Testes: `test_power.gd`, `test_assembler_ammo_from_two_belts`.

### Fase 4 — Combate
- Torre balística consome munição e para sem ela. Torre elétrica consome energia e encadeia descargas.
- Corredor contorna muros, Aríete os atravessa. Reparo consome placas.
- Testes: `test_combat.gd` (6 testes).

### Fase 5 — Integração
- Cadeia completa de munição alimenta duas torres automaticamente. Destruir uma esteira interrompe o
  abastecimento e reconstruí-la restaura. Defesa simples sobrevive às 3 primeiras hordas reais.
- Hordas, vitória/derrota, salvamento determinístico.
- Testes: `test_integration.gd`, `test_waves.gd`, `test_save.gd`, `test_belt_destroyed_cuts_supply`.

### Fase 6 — Pesquisa e progressão
- Laboratório consome Pacotes de Pesquisa (placa + componente) e Militares (munição + componente).
  Vários laboratórios dividem o trabalho sem desperdiçar pacotes.
- 10 tecnologias em `data/research.json` com pré-requisitos, modificadores e desbloqueios. Estruturas e
  receitas bloqueadas ficam visíveis na barra com o nome da pesquisa necessária.
- Conteúdo novo: Torre de Canhão, Torre Antiaérea, Painel Solar, Sabotador, Planador.
- Objetivos de pesquisa e antiaérea; transmissões sobre Genesis por pesquisa; patrulhas com
  sabotadores após 2 pesquisas.
- Testes: `test_research.gd` (10 testes: bloqueios, laboratório, dois laboratórios, fortificação,
  esteiras, canhão em área, voador × antiaérea, sabotador, solar, salvamento da pesquisa).

### Pendências para fases futuras
Drones de abastecimento (os de reparo já existem), novas regiões com jazidas raras e ninhos destrutíveis.

### Fase 7 — Otimização, interface e experiência
- **Desempenho:** campo de fluxo em float64 (o arredondamento em float32 causava reexpansões em
  cascata: 30 s → 80 ms numa base de 3000 estruturas), esteiras bloqueadas dormem, rede elétrica sem
  varreduras por tick. 3130 estruturas + 300 inimigos: 17 → 7–13 ms por tick.
- **Seleção em área** (Shift+arrastar) com resumo por estado, ligar/desligar, demolir e custo de réplica.
- **Plantas:** copiar a seleção, girar em 90°, colar com prévia por estrutura (verde/vermelho), receitas
  e estado preservados.
- **Rastreamento de fluxo** (V): fontes e destinos de itens de qualquer estrutura.
- **Saídas consistentes com a rotação** em máquinas de tamanho par, com seta no chão marcando a saída.
- **Minimapa** clicável, **alertas clicáveis**, **dicas contextuais** (dispensáveis, lembradas entre sessões).
- **Opções:** volume, escala da interface, velocidade da câmera, tela cheia, câmera pela borda, dicas, minimapa.
- Testes: `test_tools.gd` (rastreamento, planta com custo, rotação de planta), `test_large_base_performance`,
  `test_blocked_belt_resumes_when_freed`.

### Fase 8 — Builds de teste e distribuição
- `scripts/build.sh`: exporta, testa o binário exportado e empacota (zip/tar.gz + SHA-256).
- `release.yml`: tag → versão carimbada, testes, pacotes, GitHub Release; job de upload Steam
  (`game-ci/steam-deploy`) ativado por variável + segredos; tags com sufixo vão ao branch beta.
- `steam/*.vdf` + `scripts/steam_upload.sh` para upload manual com steamcmd.
- `SteamService` (GodotSteam opcional, fallback offline), 12 conquistas locais + Steam, Rich Presence.
- Remapeamento de teclas em Opções › Controles (troca automática de conflitos, persistente).
- Testes: `test_platform.gd` (conquistas e persistência, estatísticas de elite/sem perdas,
  remapeamento, fallback offline, ids das conquistas).

### Revisão de esteiras e saídas (feedback de jogo)
- Máquinas entregam por **qualquer tile do lado da frente**, marcado por uma faixa amarela brilhante e
  setas no chão. Antes era um único tile, difícil de enxergar.
- Esteiras com superfície animada (setas no sentido do fluxo; vermelhas quando travadas), **curvas**
  automáticas quando alimentadas pela lateral (itens seguem o arco), tampa vermelha em fim sem destino,
  prévia de construção já mostra a curva.
- Dicas de passar o mouse explicam direção, curva e destino de cada esteira e o lado de saída das máquinas.
- Testes: saída por qualquer tile da frente, forma das esteiras e fim sem destino, geometria das curvas.

### Pendências gerais
Suporte a controle / Steam Deck, perfil de renderização em GPU dedicada.

## Como executar

Veja o README. Testes: `GODOT=godot tests/run.sh`. Ciclo completo automatizado: `godot --headless --path . -- --smoke`.

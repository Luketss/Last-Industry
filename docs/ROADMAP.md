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
| 7 | Otimização, interface e experiência | 🟡 Diagnóstico, depuração e MultiMesh prontos. Faltam seleção em área, blueprints, opções |
| 8 | Builds de teste e distribuição Steam | 🟡 Exports e CI prontos. Falta integração Steamworks (ver STEAM.md) |

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
Cuspidor (ácido em área), drones de reparo/abastecimento, sensor de horda, névoa de guerra,
terminais de lore nas ruínas e a estrutura final Genesis com os três finais.

### Fase 7 — Próximos passos
Seleção em retângulo e cópia/colagem de áreas (blueprints), filtros no divisor, menu de opções
(volume, resolução, idioma, teclas), tutorial contextual, tooltips de rastreamento de origem de
recursos, perfil de desempenho com 1000+ estruturas.

## Como executar

Veja o README. Testes: `GODOT=godot tests/run.sh`. Ciclo completo automatizado: `godot --headless --path . -- --smoke`.

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
| 6 | Pesquisa, objetivos e progressão | 🟡 Objetivos, narrativa e modo sobrevivência prontos. Falta a árvore de pesquisa |
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

### Fase 6 — Próximos passos
1. Laboratório + pacotes de pesquisa (nova receita) + `data/research.json`.
2. Árvore inicial: mineradora II, esteira rápida, torre de canhão (dano em área), munição perfurante,
   painel solar, sensor de horda (aviso antecipado), drone de reparo.
3. Inimigos 4–6: sabotador (alvo = geradores/esteiras), voador (ignora muros, exige antiaérea), cuspidor (ácido em área).
4. Névoa de guerra e terminais de lore nas ruínas.

### Fase 7 — Próximos passos
Seleção em retângulo e cópia/colagem de áreas (blueprints), filtros no divisor, menu de opções
(volume, resolução, idioma, teclas), tutorial contextual, tooltips de rastreamento de origem de
recursos, perfil de desempenho com 1000+ estruturas.

## Como executar

Veja o README. Testes: `GODOT=godot tests/run.sh`. Ciclo completo automatizado: `godot --headless --path . -- --smoke`.

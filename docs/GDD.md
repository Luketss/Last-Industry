# Last Industry — Documento de Design

## Premissa

> A humanidade não acabou. Ela ficou sem nada para produzir.

Décadas depois do colapso, um complexo industrial subterrâneo desperta com uma única diretriz:
**MANTER A PRODUÇÃO. PRESERVAR O NÚCLEO. SOBREVIVER.** O jogador reativa a instalação sem lembrar
de ter recebido essa missão. Cada máquina restaurada aproxima o complexo de seu antigo potencial e
também o torna visível. Nas ruínas, algo percebeu que a indústria voltou a funcionar.

## Pilares

1. **Produzir para sobreviver.** A fábrica é a maior vantagem e a maior vulnerabilidade. Defesa sem
   indústria não existe: munição é fabricada, torres elétricas disputam energia com as máquinas,
   reparos consomem placas.
2. **A fábrica é a protagonista.** A narrativa é contada pelo ambiente e pelas consequências:
   setores reconstruídos, ruínas de máquinas destruídas, transmissões fragmentadas.
3. **Nunca saber tudo.** A ameaça é sentida antes de ser compreendida. Hordas anunciadas informam
   o suficiente para preparar. Patrulhas sem aviso punem perímetros negligenciados.

## Atmosfera

- Céu de cinzas, partículas de cinza caindo, ruínas de concreto, luz industrial limitada.
- Dia cinzento e quente, noite fria durante as hordas. O núcleo pulsa vermelho no alarme.
- Paleta: concreto, ferrugem, metal escuro. Emissivos laranja (calor e fornos) e ciano (energia).
- Som: vento, zumbido elétrico que cresce com a fábrica, alarmes, disparos. Silêncio como recurso.

## Ciclo de jogo

```
explorar jazidas → extrair → processar → montar → abastecer defesas
        ↑                                              ↓
  reconstruir ← hordas destroem estruturas ← hordas ao anoitecer
```

**Curto prazo:** objetivos guiados (primeira mineradora, placas, energia, munição, primeira torre
abastecida). **Médio:** sobreviver às hordas, expandir para jazidas ricas e distantes, criar redes
elétricas separadas e linhas reserva. **Longo:** derrotar o chefe da 10ª horda; depois, o modo
Sobrevivência com hordas crescentes.

## Interdependências (implementadas)

| Dependência | Consequência para o jogador |
|---|---|
| Munição = placa + carvão + energia | Uma falha em qualquer elo silencia as torres balísticas |
| Torres balísticas consomem pentes | Sem esteira de abastecimento, param de atirar ("sem munição") |
| Gerador queima carvão | O carvão é disputado entre energia e munição |
| Torre elétrica consome 110 kW | Compete com a produção. Prioridade de defesa pode parar a fábrica |
| Estação de reparo consome placas | Reparar custa material que expandiria a base |
| Esteiras têm 40 de integridade | Um rastejante numa esteira pode desabastecer várias torres |
| Redes separadas | Um poste destruído isola só um setor |
| Depósito como buffer | Reserva de munição mantém as torres durante uma interrupção |

## Estruturas (MVP)

Núcleo, Esteira, Divisor, Depósito, Mineradora, Fundição, Montadora, Gerador a Carvão, Poste,
Banco de Baterias, Torre Balística, Torre Elétrica, Muro, Estação de Reparo. Números em
`data/buildings.json`.

## Inimigos (MVP)

| Inimigo | Papel | Comportamento |
|---|---|---|
| Rastejante | Básico | Segue a rota e morde qualquer estrutura próxima |
| Corredor | Rápido | Evita muros fortemente, procura brechas até o núcleo |
| Aríete | Destruidor de muros | Blindado, lento, atravessa muros, dano em área |
| Elite/Chefe | Variante | Multiplicadores de vida, tamanho e dano definidos na horda |

| Sabotador | Infraestrutura | Caça geradores, painéis, baterias, postes, esteiras e laboratórios num raio de 4,5 |
| Planador | Voador | Ignora muros e terreno, voa até a infraestrutura. Só Antiaérea e Torre Elétrica o atingem |

| Cuspidor | À distância | Cospe ácido a até 4 tiles por cima dos muros, com dano em área; prefere torres e máquinas |

Planejados: mais mudanças de comportamento ligadas à pesquisa.

## Narrativa: o Projeto Genesis

Revelada por **transmissões** (painel esquerdo) disparadas por eventos: início, objetivos, hordas
anunciadas, iniciadas e repelidas (`data/lore.json`). Arco planejado:

1. **Sobreviver:** a instalação desperta, as primeiras hordas chegam.
2. **Expandir:** novas jazidas, registros sobre vibrações e a assinatura térmica do complexo.
3. **Descobrir:** arquivos sobre Genesis, uma tecnologia capaz de reconstruir ecossistemas, e um
   protocolo de contenção: *não permitir que a produção seja reiniciada*.
4. **Decidir:** ativar Genesis. Três finais: restaurar o mundo, destruir a tecnologia, ou continuar
   produzindo para sempre como fortaleza autossuficiente.

**Implementado:** a pesquisa *Protocolo Genesis* libera a Estrutura Genesis (3×3, 150 kW). Ela
precisa de energia contínua por 4 minutos; durante a carga, surtos de criaturas saem de todos os
ninhos a cada 22 s, crescendo com o progresso. Com a carga completa, a simulação para e o jogador
escolhe RESTAURAR, DESTRUIR ou MANTER (este segue no modo Sobrevivência). Quatro **terminais de
dados** perto das ruínas contam a história de Genesis: decodificar exige uma estrutura a até 7
tiles e rende sucata. Conquistas para cada final e para ler os quatro terminais.

Conforme a pesquisa avança, as hordas passam a priorizar setores específicos e novas criaturas
aparecem perto de estruturas avançadas. A ameaça reage ao que você fabrica.

## Pesquisa (implementada)

O Laboratório consome Pacotes de Pesquisa (placa + componente) e Pacotes Militares (munição +
componente), fabricados na Montadora. Pesquisar custa recursos que poderiam virar munição: é uma
aposta no futuro contra a próxima horda. Árvore atual (`data/research.json`): Automação Básica,
Perfuração Profunda, Esteiras Reforçadas, Energia Solar, Logística Militar, Defesa Antiaérea,
Artilharia, Balística Avançada, Fortificação, Fragmento Genesis.

## Progressão futura

- **Pesquisa adicional:** torre de longo alcance, ácido, munições especiais, robôs de
  construção/reparo, turbinas e sensores de emergência.
- **Exploração:** névoa de guerra, regiões com jazidas raras, terminais com arquivos de Genesis,
  ninhos que podem ser destruídos.
- **Estrutura final:** construção que encerra a campanha (ativação de Genesis).

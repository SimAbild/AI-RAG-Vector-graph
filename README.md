# RAG-projekt: Opskrift-assistent (vector + graph i Neo4j, n8n, Ollama)

## Case

Domænet er en lille samling danske opskrifter (5 stk: Spaghetti Bolognese, Grøntsagslasagne, Thai Kyllingecurry, Tomatsuppe, Æblekage), bevidst designet med overlappende ingredienser (tomat, løg, hvidløg) og kategorier, så både graph- og vector-søgning har noget meningsfuldt at demonstrere.

**Agentens rolle:** en hjælpsom opskrift-assistent, der finder opskrifter enten ud fra en beskrivelse ("noget med kylling og karry" → semantisk/vector) eller ud fra konkrete kriterier ("opskrifter med tomat" → struktureret/graph). Fuld system prompt i `agent/system-prompt.txt`.

## Hvordan komponenterne hænger sammen

```
                     ┌───────────────────────┐
                     │   Opskrift Ingestion   │
                     │  (workflows/opskrift-  │
                     │     ingestion.json)    │
                     └───────────┬────────────┘
                                 │ populerer
                                 ▼
                     ┌───────────────────────┐
                     │         Neo4j         │
                     │  graph + vector-index  │
                     └───────┬───────┬────────┘
                   hentes af │       │ hentes af
                             ▼       ▼
         ┌───────────────────────┐ ┌───────────────────────┐
         │ Opskrift Vector Search│ │ Opskrift Graph Search  │
         │  (semantisk søgning)  │ │ (struktureret opslag)  │
         └───────────┬───────────┘ └───────────┬───────────┘
                      │        tools kaldt af   │
                      └───────────┬─────────────┘
                                  ▼
                       ┌───────────────────────┐
                       │     Opskrift Agent      │
                       │  (Ollama llama3.2 +     │
                       │   begge tools)          │
                       └───────────────────────┘
```

- **Ingestion** læser opskrifterne, chunker fremgangsmåden, laver embeddings via Ollama (`nomic-embed-text`) og skriver *både* graf-struktur (Recipe/Category/Ingredient + relationer) og vector-chunks til Neo4j i samme Cypher-kald.
- **Vector Search** og **Graph Search** er selvstændige n8n-workflows, der hver kaldes som et "tool" fra agent-workflowet.
- **Agent** bruger en lokal Ollama chat-model (`llama3.2`) og vælger selv mellem de to retrieval-tools ud fra spørgsmålets formulering.

Alt kører over Docker (n8n + Ollama i containere på samme netværk), undtagen Neo4j som kører lokalt (Neo4j Desktop).

## Hvor finder du filerne

| Krav | Placering |
|---|---|
| Workflow JSON (alle 4) | `workflows/` |
| Workflow-skærmbilleder (mærket efter formål) | `screenshots/` — vist direkte nedenfor |
| Agent-konfiguration og prompts | `agent/system-prompt.txt`, `agent/tool-descriptions.md` |
| Model-sammenligning (llama3.2 vs. qwen2.5) | `agent/model-comparison.md` — skærmbilleder vist nedenfor |
| Tre eksempelspørgsmål + resultater + vurdering | `examples/example-questions-results.md` — skærmbilleder vist nedenfor |
| Data og setup | `data/` — se nedenfor |

## Workflow-overblik

Alle fire workflows, mærket efter formål (sticky note i hvert workflow beskriver formålet).

**Data ingestion** — læser opskrifterne, chunker, embedder (Ollama) og skriver både graf og vector-chunks til Neo4j:

![Opskrift Ingestion](screenshots/workflow-ingestion.png)

**Vector retrieval** — semantisk søgning via Neo4js vektorindeks:

![Opskrift Vector Search](screenshots/workflow-vector-search.png)

**Graph retrieval** — struktureret opslag via graf-relationer:

![Opskrift Graph Search](screenshots/workflow-graph-search.png)

**AI Agent** — bruger begge ovenstående som tools:

![Opskrift Agent](screenshots/workflow-agent.png)

**Agentens tool-forbindelser** (Ollama Chat Model + de to retrieval-tools forbundet til AI Agent-noden):

![Agent tool-forbindelser](screenshots/agent-tool-connections.png)

## Eksempelspørgsmål (resumé — fuld vurdering i `examples/example-questions-results.md`)

**1. "Jeg har lyst til noget med kylling og karry"** (Vector Search Tool) — fandt korrekt Thai Kyllingecurry, men blandede et irrelevant 3. resultat ind og behandlede to chunks fra samme opskrift som to forskellige retter:

![Spørgsmål 1](screenshots/chat-example-1.png)

**2. "Hvilke opskrifter indeholder tomat?"** (Graph Search Tool) — afslørede en tool-schema-bug (`category`-parameter var fejlagtigt required); efter rettelsen svarer agenten korrekt med de tre rigtige opskrifter:

![Spørgsmål 2](screenshots/chat-example-2.png)

**3. "Findes der en opskrift med rejer?"** (Vector Search Tool) — bekræftet begrænsning: retrieval fandt korrekt intet match (lave similarity-scorer), men agenten svarede alligevel "ja" og opfandt en falsk ingrediens på to rigtige opskrifter:

![Spørgsmål 3](screenshots/chat-example-3.png)

## Model-eksperiment: llama3.2 vs. qwen2.5 (resumé — fuld sammenligning i `agent/model-comparison.md`)

qwen2.5 citerede hentet tekst mere præcist (spørgsmål 1), men havde en strukturel fejl i tool-kald til Graph Search (afviste valgfrie parametre) og degenererede i ét tilfælde til urelateret, delvist kinesisk tekst. Jeg beholdt `llama3.2:latest` som endelig model.

![qwen2.5 — spørgsmål 1](screenshots/model-comparison/q1-qwen.png)
![qwen2.5 — tool-fejl](screenshots/model-comparison/q2-qwen-tool-error.png)
![qwen2.5 — spørgsmål 2+3 i chatten](screenshots/model-comparison/q2-q3-qwen-chat.png)

## Data og setup

- **Datakilde:** 5 selvskrevne eksempelopskrifter, se `data/opskrifter.md` (læsbar) og `data/alle-opskrifter.json` (strukturerede rådata, bruges direkte i ingestion-workflowets kode-node).
- **Node-typer:** `Recipe { name }`, `Category { name }`, `Ingredient { name }`, `Chunk { recipeName, chunkIndex, text, embedding }`.
- **Relationer:** `(Recipe)-[:CONTAINS]->(Ingredient)`, `(Recipe)-[:BELONGS_TO]->(Category)`, `(Recipe)-[:HAS_CHUNK]->(Chunk)`.
- **Embedding-model:** Ollama `nomic-embed-text`, 768 dimensioner, cosine similarity.
- **Chat-model:** Ollama `llama3.2:latest`.
- **Genskab databasen:** kør `data/neo4j-setup.cypher` i Neo4j Browser (constraints + vektorindeks), importér derefter `workflows/opskrift-ingestion.json` i n8n og kør det én gang. Se filen for forventede node-tal efter en korrekt kørsel.

## Kendt begrænsning

**Vigtigere begrænsning, bekræftet ved test:** i spørgsmål 3 (se `examples/example-questions-results.md`) hentede Vector Search Tool korrekt, relevant data fra Neo4j — men agentens endelige svar ignorerede det hentede data og opfandt i stedet en ingrediens, der ikke findes (en falsk påstand om, at Tomatsuppe og Æblekage indeholder rejer). Dette er ikke en retrieval-fejl, men en grounding-svaghed i den lokale `llama3.2:latest`-model (3B), som ikke pålideligt holder sig til den kontekst, værktøjerne returnerer.

Under test af spørgsmål 2 blev der desuden fundet og rettet en separat, teknisk fejl: Graph Search Tool-noden definerede sin `category`-parameter via `$fromAI(...)` uden default-værdi, hvilket gjorde den fejlagtigt required i det skema, der sendes til sprogmodellen, og fik kald uden en angivet kategori til at fejle med en skema-valideringsfejl (`Received tool input did not match expected schema`). Rettet ved at tilføje en tom streng som default — se spørgsmål 2 i `examples/example-questions-results.md` for detaljer.

Jeg afprøvede også `qwen2.5:latest` som alternativ chat-model for at undersøge, om en anden lokal model klarede sig bedre — se `agent/model-comparison.md` for den fulde sammenligning. Kort fortalt: qwen2.5 var bedre til at citere hentet tekst korrekt, men havde til gengæld en strukturel kompatibilitetsfejl med Graph Search-værktøjet (afviste valgfrie parametre), som i et tilfælde førte til fuldstændig urelateret hallucination. Jeg beholdt `llama3.2:latest` som den endelige model, da dens fejlmønster er mere forudsigeligt.

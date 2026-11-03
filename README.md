# RAG-projekt: Opskrift-assistent (vector + graph i Neo4j, n8n, Ollama)

## Case

Domænet er en lille samling opskrifter (5 stk: Spaghetti Bolognese, Grøntsagslasagne, Thai Kyllingecurry, Tomatsuppe, Æblekage), bevidst designet med overlappende ingredienser (tomat, løg, hvidløg) og kategorier, så både graph- og vector-søgning har noget meningsfuldt at demonstrere.

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
| Workflow-skærmbilleder (mærket efter formål) | `screenshots/` — se `screenshots/README.md` for liste |
| Agent-konfiguration og prompts | `agent/system-prompt.txt`, `agent/tool-descriptions.md` |
| Model-sammenligning (llama3.2 vs. qwen2.5) | `agent/model-comparison.md` |
| Tre eksempelspørgsmål + resultater + vurdering | `examples/example-questions-results.md` |
| Data og setup | `data/` — se nedenfor |

## Data og setup

- **Datakilde:** 5 selvskrevne eksempelopskrifter, se `data/opskrifter.md` (læsbar) og `data/alle-opskrifter.json` (strukturerede rådata, bruges direkte i ingestion-workflowets kode-node).
- **Node-typer:** `Recipe { name }`, `Category { name }`, `Ingredient { name }`, `Chunk { recipeName, chunkIndex, text, embedding }`.
- **Relationer:** `(Recipe)-[:CONTAINS]->(Ingredient)`, `(Recipe)-[:BELONGS_TO]->(Category)`, `(Recipe)-[:HAS_CHUNK]->(Chunk)`.
- **Embedding-model:** Ollama `nomic-embed-text`, 768 dimensioner, cosine similarity.
- **Chat-model:** Ollama `llama3.2:latest`.
- **Genskab databasen:** kør `data/neo4j-setup.cypher` i Neo4j Browser (constraints + vektorindeks), importér derefter `workflows/opskrift-ingestion.json` i n8n og kør det én gang. Se filen for forventede node-tal efter en korrekt kørsel.

## Kendt begrænsning

**En begrænsning, bekræftet ved test:** i to af de tre eksempelspørgsmål (se `examples/example-questions-results.md`, spørgsmål 2 og 3) hentede både Graph Search Tool og Vector Search Tool korrekt, relevant data fra Neo4j — men agentens endelige svar ignorerede det hentede data og opfandt i stedet opskrifter/ingredienser, der ikke findes (bl.a. en falsk påstand om, at Tomatsuppe og Æblekage indeholder rejer). Dette er ikke en retrieval-fejl, men en grounding-svaghed i den lokale `llama3.2:latest`-model (3B), som ikke pålideligt holder sig til den kontekst, værktøjerne returnerer.

Jeg afprøvede også `qwen2.5:latest` som alternativ chat-model for at undersøge, om en anden lokal model klarede sig bedre — se `agent/model-comparison.md` for den fulde sammenligning. Kort fortalt: qwen2.5 var bedre til at citere hentet tekst korrekt, men havde til gengæld en strukturel kompatibilitetsfejl med Graph Search-værktøjet (afviste valgfrie parametre), som i et tilfælde førte til fuldstændig urelateret hallucination. Jeg beholdt `llama3.2:latest` som den endelige model, da dens fejlmønster er mere forudsigeligt.

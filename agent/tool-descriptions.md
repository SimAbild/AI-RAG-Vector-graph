# Agentens værktøjer (tools)

Agenten har to retrieval-workflows forbundet som tools. Begge er separate n8n-workflows, kaldt via "Execute Workflow"-tool-noder, og begge returnerer tekst/fakta direkte fra Neo4j (aldrig genereret af modellen selv).

## 1. Opskrift Vector Search

**Fil:** `workflows/opskrift-vector-search.json`

**Hvad den gør:** Semantisk søgning. Embedder brugerens forespørgsel (Ollama, `nomic-embed-text`, 768 dim) og finder de 3 mest similar tekst-chunks fra opskrifternes fremgangsmåde via Neo4js vektorindeks (`chunkEmbeddings`, cosine similarity).

**Input:** `query` (string) — en naturlig sprog-beskrivelse af hvad brugeren har lyst til, f.eks. "noget med kylling og karry".

**Output (kilde):** chunk-tekst, opskriftsnavn og similarity-score, højest først — direkte fra `Chunk`-noder i Neo4j.

**Hvornår agenten skal bruge den:** Når brugeren beskriver en smag/stemning/ønske frem for at nævne en konkret ingrediens eller kategori — dvs. når spørgsmålet kræver at forstå *betydning*, ikke bare matche et felt.

## 2. Opskrift Graph Search

**Fil:** `workflows/opskrift-graph-search.json`

**Hvad den gør:** Struktureret opslag via graf-traversal. Matcher `Recipe`-noder mod deres `CONTAINS`- (Ingredient) og `BELONGS_TO`- (Category) relationer i Neo4j.

**Input:** `ingredient` (string, valgfri), `category` (string, valgfri). Tomme felter sendes som `null` og filtrerer ikke.

**Output (kilde):** opskriftsnavn, fuld ingrediensliste og kategoriliste — direkte fra graf-relationerne i Neo4j.

**Hvornår agenten skal bruge den:** Når brugeren nævner en konkret, navngiven ingrediens eller kategori — dvs. når spørgsmålet kan besvares med et præcist filter/match.

---

Begge værktøjers beskrivelser er også defineret direkte på tool-node'rne i `workflows/opskrift-agent.json`, så modellen selv kan vælge det rigtige værktøj ud fra spørgsmålets formulering (eller begge, hvis relevant).

# Model-eksperiment: llama3.2 vs. qwen2.5 som agentens chat-model

Som led i at undersøge agentens begrænsninger (se `examples/example-questions-results.md`) blev agentens chat-model midlertidigt skiftet fra `llama3.2:latest` til `qwen2.5:latest` (begge kørende lokalt via Ollama i Docker, samme credential, ingen andre ændringer) for at se, om en anden lokal model havde bedre "grounding" i det hentede data. Afleveringens endelige opsætning bruger `llama3.2:latest` (se begrundelse nedenfor).

Skærmbilleder af qwen2.5-testene ligger i `../screenshots/model-comparison/`.

## Resultater

| Spørgsmål | llama3.2 | qwen2.5 |
|---|---|---|
| "kylling og karry" (Vector Search) | Korrekt indhold, men omskrevet/let upræcist, viste samme opskrift to gange | **Bedre**: citerede de hentede chunks ordret, droppede selv det irrelevante 3. resultat. Viste dog stadig samme opskrift (Thai Kyllingecurry) to gange. |
| "tomat" (Graph Search) | Opfandt 5 ikke-eksisterende opskrifter og 2 ikke-eksisterende kategorier — alvorlig guardrail-overtrædelse | **Værre**: selve værktøjskaldet fejlede ("Received tool input did not match expected schema ✗ Required → at category") — qwen2.5 udelod det valgfrie `category`-felt helt i stedet for at sende en tom værdi. Efter fejlen degenererede svaret til usammenhængende, delvist kinesisk tekst om et helt urelateret emne (en politiker i Georgien). |
| "rejer" (Vector/Graph Search) | Opfandt, at Tomatsuppe og Æblekage indeholder rejer, selvom retrieval korrekt ikke fandt noget match | Samme værktøjsfejl som ovenfor opstod igen, men denne gang endte svaret korrekt ("kunne ikke finde..."), med en mindre sprogblanding (et enkelt engelsk ord i en dansk sætning). |

![qwen2.5 — spørgsmål 1 (Vector Search, korrekt citering)](../screenshots/model-comparison/q1-qwen.png)

![qwen2.5 — spørgsmål 2 (Graph Search Tool-fejl: skema afviser udeladt category-felt)](../screenshots/model-comparison/q2-qwen-tool-error.png)

![qwen2.5 — spørgsmål 2+3 i chatten (hallucination efter værktøjsfejl, derefter korrekt "kunne ikke finde")](../screenshots/model-comparison/q2-q3-qwen-chat.png)

## Konklusion

qwen2.5 er bedre til at citere/holde sig tæt til tekst, den rent faktisk modtager (spørgsmål 1), men har en **strukturel kompatibilitetsfejl** med mit Graph Search-værktøj i denne n8n-opsætning: den udelader valgfrie parametre i sine tool-kald, hvilket n8n's skema-validering afviser som en fejl. Det gør dens opførsel efter en værktøjsfejl uforudsigelig — fra et korrekt "jeg kan ikke finde det" til fuldstændig urelateret hallucination. Dette er en dybere og mere alvorlig fejltype end llama3.2's problem (som i det mindste altid kalder værktøjerne korrekt, men ikke altid holder sig til deres resultat i det endelige svar).

**Beslutning:** Jeg beholder `llama3.2:latest` som afleveringens chat-model, da dens fejlmønster er mere forudsigeligt og lettere at dokumentere og forklare. Begge modellers svagheder underbygger samlet set projektets hovedkonklusion: lokale, små (3B-klasse) sprogmodeller er ikke fuldt pålidelige til at holde sig til RAG-hentet kontekst eller til konsistent tool-calling, uanset hvilken af de to jeg afprøvede.

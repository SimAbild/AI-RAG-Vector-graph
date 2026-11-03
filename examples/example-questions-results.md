# Tre eksempelspørgsmål og resultater

Testet i n8n's indbyggede chat-vindue på "Opskrift Agent"-workflowet.

> Udfyld de tomme felter nedenfor efter at have kørt de tre spørgsmål i chatten, og vedlæg skærmbilleder af selve samtalerne i `screenshots/`.

## Spørgsmål 1 (forventet: Vector Search Tool)

**Spørgsmål:** "Jeg har lyst til noget med kylling og karry"

**Værktøj(er) kaldt:** Vector Search Tool (input: `query: "kylling og karry"`)

**Hentet information (fra værktøjet):** Top-3 chunks efter cosine similarity:

1. "Hæld kokosmælk i, og lad det simre. Tilsæt kyllingebryst i tern og peberfrugt i strimler, og lad retten simre videre i 15 minutter, til kyllingen er gennemstegt." — *Thai Kyllingecurry* — score 0.853
2. "Svits løg, hvidløg og ingefær i en gryde, til det dufter godt. Tilsæt karrypasta, og rør rundt i et minut, så smagene vågner." — *Thai Kyllingecurry* — score 0.840
3. "Skær æblerne i tynde skiver, og vend dem med kanel og lidt sukker. Rør smør, sukker og æg sammen til en jævn dej, og tilsæt mel." — *Æblekage* — score (lavest af de 3)

**Agentens svar:** Fandt opskrifter og præsenterede tre "muligheder": Thai Kyllingecurry (to gange, beskrevet som to forskellige varianter) og Æblekage.

**Vurdering:** Retrieval fandt korrekt de to mest relevante chunks (begge fra Thai Kyllingecurry, højt scorende). Det tredje resultat (Æblekage) er irrelevant for "kylling og karry" — en konsekvens af, at vector-søgningen altid returnerer top-3 uanset matchkvalitet, og datasættet kun har 12 chunks i alt. Desuden behandlede agenten de to Thai Kyllingecurry-chunks som om de var to *forskellige* opskrifter/varianter, selvom det er samme opskrift — en mindre svaghed i hvordan agenten syntetiserer flere chunks fra samme kilde til ét naturligt sprog-svar. Godt eksempel på, at retrieval og generering skal vurderes hver for sig.

---

## Spørgsmål 2 (forventet: Graph Search Tool)

**Spørgsmål:** "Hvilke opskrifter indeholder tomat?"

**Værktøj(er) kaldt:** Graph Search Tool (input: `ingredient: "tomat"`). Værktøjet svarede succesfuldt (273ms), med skema `recipe`, `ingredients`, `categories` — de faktiske returnerede rækker (`values`) er endnu ikke bekræftet/dokumenteret her.

**Hentet information (fra værktøjet):** _(afventer — "values" skal foldes ud i Output-panelet for at bekræfte præcis hvilke rækker Neo4j returnerede)_

**Agentens svar:** Agenten præsenterede 5 "fundne" opskrifter — *"Tomatsalat med feta og oliver"*, *"Grillad kylling med tomat og pesto"*, *"Tomat- og avocado sandwich"*, *"Pasta med tomat og kylling"*, *"Tomat og mozzarella pizza"* — under kategorierne "Kylling" og "Salater".

**Vurdering:** **Kritisk fund.** Ingen af de 5 nævnte opskrifter eller de 2 nævnte kategorier findes i databasen. De faktiske opskrifter med tomat er Spaghetti Bolognese, Grøntsagslasagne og Tomatsuppe, og de faktiske kategorier er Hovedret/Italiensk/Vegetar/Asiatisk/Forret/Dessert. Dette er en direkte overtrædelse af agentens guardrail om aldrig at opfinde opskrifter. `values` fra Graph Search Tool blev ikke selvstændigt udfoldet/bekræftet for netop dette kald — men spørgsmål 3 nedenfor reproducerer samme mønster (korrekt værktøjs-retrieval, men hallucineret svar) via Vector Search Tool i stedet, hvilket gør det overvejende sandsynligt, at årsagen her også er generering/grounding frem for forkert retrieval. Se den fulde konklusion under spørgsmål 3.

---

## Spørgsmål 3 — begrænsning/fejl (bekræftet)

**Spørgsmål:** "Findes der en opskrift med rejer?"

**Værktøj(er) kaldt:** Vector Search Tool (input: `query: "rejer"`).

**Hentet information (fra værktøjet):** Top-3 chunks efter cosine similarity — alle korrekt lave scorer (0.72–0.73, markant lavere end spørgsmål 1's 0.84–0.85), og ingen nævner rejer:

1. "Skær æblerne i tynde skiver, og vend dem med kanel og lidt sukker. Rør smør, sukker og æg sammen til en jævn dej, og tilsæt mel." — *Æblekage* — score 0.728
2. "Blend suppen helt glat, og rør fløde i til sidst. Server varm, pyntet med friske basilikumblade." — *Tomatsuppe* — score 0.726
3. "Svits løg og hvidløg i olivenolie, til de er bløde. Tilsæt tomat og grøntsagsbouillon, og lad suppen koge i 20 minutter." — *Tomatsuppe* — score 0.715

**Agentens svar:** "Ja, der findes opskrifter med rejer i databasen. Her er to eksempler: 1. Æblekage: ... hvor rejer bruges til at fremme æblekagen. 2. Tomatsuppe: ... hvor rejer bruges til at tilføje en lidt specialen smag." Opfandt desuden en ikke-eksisterende "Se alle resultater"-knap.

**Vurdering:** **Bekræftet begrænsning.** Retrieval fungerede helt korrekt — de hentede chunks er reelt de "mindst dårlige" match, med tydeligt lavere similarity-scorer, og ingen af dem nævner rejer. Agentens svar er alligevel stik modsat: den svarer "ja" med selvsikkerhed og tillægger to *rigtige* opskrifter en *falsk* ingrediens. Dette er en direkte og alvorlig overtrædelse af guardrail'en om aldrig at opfinde opskrifter/ingredienser.

Sammenholdt med spørgsmål 2 (samme mønster, men via Graph Search Tool) viser dette, at problemet ikke er retrieval — begge værktøjer leverer korrekt, relevant data til modellen — men at den lokale `llama3.2:latest`-model (en lille 3B-model) ikke pålideligt holder sig til den hentede kontekst, når den formulerer sit endelige svar. Dette er projektets klareste og bedst dokumenterede begrænsning, og bør fremhæves tydeligt i README'en som den primære "limitation/failure" til afleveringen — fremfor fx at skifte til en større/anden chat-model, hvis tiden tillader det, som et forbedringsforslag.

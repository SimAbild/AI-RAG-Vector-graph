// Neo4j-opsætning til Opskrift RAG-projektet
// Kør i rækkefølge i Neo4j Browser (http://localhost:7474)
// VIGTIGT: ryd altid databasen FØR du opretter constraints — Neo4j nægter at
// oprette et unikheds-constraint, hvis der allerede findes duplikerede værdier.

// 1. Ryd databasen (kun nødvendigt ved gentest/nulstilling)
MATCH (n) DETACH DELETE n;

// 2. Unikheds-constraints (normaliserer grafen og forhindrer duplikater ved gentagne ingestion-kørsler)
CREATE CONSTRAINT recipe_name_unique IF NOT EXISTS FOR (r:Recipe) REQUIRE r.name IS UNIQUE;
CREATE CONSTRAINT category_name_unique IF NOT EXISTS FOR (c:Category) REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT ingredient_name_unique IF NOT EXISTS FOR (i:Ingredient) REQUIRE i.name IS UNIQUE;
CREATE CONSTRAINT chunk_key_unique IF NOT EXISTS FOR (ch:Chunk) REQUIRE (ch.recipeName, ch.chunkIndex) IS UNIQUE;

// 3. Vektorindeks til semantisk søgning (768 dimensioner = Ollama nomic-embed-text)
CREATE VECTOR INDEX chunkEmbeddings IF NOT EXISTS
FOR (c:Chunk) ON (c.embedding)
OPTIONS {indexConfig: {
  `vector.dimensions`: 768,
  `vector.similarity_function`: 'cosine'
}};

// 4. Kør derefter "Opskrift Ingestion"-workflowet i n8n (workflows/opskrift-ingestion.json) for at populere grafen.

// --- Verificering efter ingestion ---
// Forventede tal med de 5 eksempelopskrifter i data/alle-opskrifter.json:
MATCH (r:Recipe) RETURN count(r);      // forventet: 5
MATCH (c:Category) RETURN count(c);    // forventet: 6
MATCH (i:Ingredient) RETURN count(i);  // forventet: ca. 31
MATCH (c:Chunk) RETURN count(c);       // forventet: ca. 12

// --- Node-typer, relationer og properties ---
// (Recipe)-[:CONTAINS]->(Ingredient)
// (Recipe)-[:BELONGS_TO]->(Category)
// (Recipe)-[:HAS_CHUNK]->(Chunk)
//
// Recipe:     { name }
// Category:   { name }
// Ingredient: { name }
// Chunk:      { recipeName, chunkIndex, text, embedding (768-dim float array) }

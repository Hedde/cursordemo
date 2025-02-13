# ICTU Cursor Demo

Cursor Demo is een [Phoenix LiveView](https://www.phoenixframework.org/) applicatie. Deze repository maakt gebruik van Docker Compose voor lokale ontwikkeling, het draaien van tests en het uitrollen van assets.

## Inhoudsopgave
1. [Installatie en Vereisten](#installatie-en-vereisten)
2. [Ontwikkelomgeving Starten](#ontwikkelomgeving-starten)
3. [Statics Uitrollen](#statics-uitrollen)
4. [Database Reset](#database-reset)
5. [Project Compileren](#project-compileren)
6. [Tests Draaien](#tests-draaien)

---

## Installatie en Vereisten

- [Docker](https://docs.docker.com/get-docker/) en [Docker Compose](https://docs.docker.com/compose/) zijn vereist om dit project lokaal te kunnen draaien.
- Phoenix, Elixir en Erlang hoeven niet per se lokaal geïnstalleerd te zijn, omdat deze via de Docker-container worden geïnstalleerd.

> **Tip**: Wil je lokaal (buiten Docker om) ontwikkelen, zorg dan dat je [Elixir](https://elixir-lang.org/install.html), [Erlang](https://www.erlang.org/downloads) en [Phoenix](https://hexdocs.pm/phoenix/installation.html) hebt geïnstalleerd. Daarnaast heb je PostgreSQL nodig als database.

---

## Ontwikkelomgeving Starten

Om een lokale ontwikkelomgeving op te zetten, gebruik je het volgende commando:

    docker compose up

Dit bouwt en start de containers (zowel de **web** container met de Phoenix-applicatie als de **db** container met PostgreSQL).

Zodra alles draait, is je applicatie bereikbaar op [http://localhost:4000](http://localhost:4000).

---

## Statics Uitrollen

Voordat je de statische bestanden (CSS, JS, etc.) uitrolt (bijvoorbeeld voor productie), kun je onderstaand commando gebruiken:

    docker compose exec web mix assets.deploy

Dit zal de benodigde assets compileren, minifyen en in de juiste mappen plaatsen, zodat ze klaarstaan voor de applicatie in productie.

---

## Database Reset

Wil je de database opnieuw instellen (drop, create, migrate en eventueel seeds uitvoeren), gebruik dan:

    docker compose run --rm web mix ecto.reset

Het `--rm` zorgt ervoor dat de container na afloop wordt verwijderd.
De eerste keer wil je ecto.migrate draaien.

---

## Project Compileren

Om te testen of de code compileert, kun je:

    docker compose run --rm web mix compile

Dit voert de compilatie uit binnen de Docker-container en laat je weten of er compileerfouten zijn.

---

## Tests Draaien

### Alle tests

Om de tests te draaien (in de test-omgeving met zijn eigen database), gebruik je:

    docker compose run --rm -e MIX_ENV=test -e DATABASE_URL=ecto://postgres:postgres@db/cursor_demo_test web mix test --cover

### Specifieke test draaien

Kijk voor meer specialisatie van de te draaien testen in de TEST.md

---

## Veelgestelde Vragen of Problemen

1. **Ik krijg een foutmelding dat de poort al in gebruik is.**
   Controleer of er geen andere processen op poort 4000 draaien. Stop anders eerdere containers of pas de poort aan in de `docker-compose.yml`.

2. **Hoe pas ik de databaseconfiguratie aan?**
   Kijk in `config/dev.exs`, `config/test.exs` of `config/prod.exs`. De Docker Compose-configuratie gebruikt standaard `db` als host en `ecto://postgres:postgres@db/kantine_koning_[env]` als connection string.
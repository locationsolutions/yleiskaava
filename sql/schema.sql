SET client_encoding = 'UTF8';
SET search_path = public, pg_catalog;

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE keep_in_effect (
    plan_id uuid NOT NULL,
    target_plan_id uuid NOT NULL,
    CONSTRAINT no_self_ref CHECK ((plan_id <> target_plan_id))
);



COMMENT ON TABLE keep_in_effect IS 'Mitkä tietyn kaavan (plan_id) kaava-alueen sisälle osuvat vanhemmat kaavat (target_plan_id) pysyvät voimassa.';



COMMENT ON COLUMN keep_in_effect.plan_id IS 'Viittaus kaavapäätökseen';



COMMENT ON COLUMN keep_in_effect.target_plan_id IS 'Viittaus vanhempaan kaavapäätökseen, joka jää voimaan';



CREATE TABLE object (
    object_id uuid NOT NULL,
    geom geometry(Geometry,3067) NOT NULL,
    plan_id uuid NOT NULL,
    CONSTRAINT object_geom_check CHECK ((st_geometrytype(geom) = ANY (ARRAY['ST_Point'::text, 'ST_Polygon'::text, 'ST_LineString'::text])))
);



COMMENT ON TABLE object IS 'Paikkatiedollinen kaavakohde, jossa kaavamääräys voi ilmentyä';



COMMENT ON COLUMN object.geom IS 'Kohteen sijainti. Joko pistemäinen, viivamainen tai aluemainen.';



COMMENT ON COLUMN object.plan_id IS 'Viittaus kaavapäätökseen, johon tämä kohde kuuluu';



CREATE TABLE object_regulation (
    object_id uuid NOT NULL,
    regulation_id uuid NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    legally_binding boolean DEFAULT true NOT NULL,
    in_effect timestamp with time zone
);



COMMENT ON TABLE object_regulation IS 'Kaavamääräyksen ilmentymä kaavakohteessa';



COMMENT ON COLUMN object_regulation.object_id IS 'Viittaus kaavakohteeseen, jossa määräys ilmenee';



COMMENT ON COLUMN object_regulation.regulation_id IS 'Viittaus kaavamääräykseen';



COMMENT ON COLUMN object_regulation.priority IS 'Määräysten keskinäinen järjestys, jos samassa kaavakohteessa ilmenee useampi määräys, esim. "M/MA". Pienemmästä suurempaan.';



COMMENT ON COLUMN object_regulation.legally_binding IS 'Oikeusvaikutteisuus. Ne ilmentymät kaavassa, jotka ovat oikeusvaikutteisia, saavat arvon TRUE. Eli kokonaan oikeusvaikutteisen kaavan kohdalla kaikki ilmentymät, osittain oikeusvaikutteisen kohdalla osa ilmentymistä ja oikeusvaikutuksettoman kohdalla ei mikään ilmentymä. Rakennuslain vahvistettu on tulkittu siirtymäsäädöksen mukaisesti oikeusvaikutteiseksi.';



COMMENT ON COLUMN object_regulation.in_effect IS 'Ajankohta, jolloin ilmentymä on tullut voimaan. NULL, jos ei vielä ole voimassa (kaavan valitusaika ei ole päättynyt tai ilmentymä on valituksen alainen).';



CREATE TABLE plan (
    plan_id uuid NOT NULL,
    geom geometry(MultiPolygon,3067) NOT NULL,
    approved timestamp with time zone,
    name_fi text,
    name_sv text,
    regulation_fi text,
    regulation_sv text,
    complete boolean DEFAULT true NOT NULL,
    syke_id text,
    regulation_pdf text
);



COMMENT ON TABLE plan IS 'Kaavapäätös';



COMMENT ON COLUMN plan.geom IS 'Kaavapäätöksen kohdealue';



COMMENT ON COLUMN plan.approved IS 'Viimeisin päätösajankohta elimessä, joka päättää kaavasta, esim. kunnanvaltuusto. Päätös, jonka jälkeen kaava tulisi lainvoimaiseksi, ellei siitä tule valituksia.';



COMMENT ON COLUMN plan.name_fi IS 'Kaavan nimi suomeksi';



COMMENT ON COLUMN plan.name_sv IS 'Kaavan nimi ruotsiksi';



COMMENT ON COLUMN plan.regulation_fi IS 'Koko kaavaa koskevat yleismääräykset / suunnittelumääräykset suomeksi';



COMMENT ON COLUMN plan.regulation_sv IS 'Koko kaavaa koskevat yleismääräykset / suunnittelumääräykset ruotsiksi';



COMMENT ON COLUMN plan.complete IS 'Onko kaava mallinnettu kokonaisuudessaan? Vanhoista rasterikaavoista digitoidaan vain yhä voimassa olevat osat, jolloin FALSE. Uusilla kaavoilla aina TRUE.';



COMMENT ON COLUMN plan.syke_id IS 'Kaavatunnus SYKE:n yleiskaavapalvelun hakemistossa';



COMMENT ON COLUMN plan.regulation_pdf IS 'URL skannattuihin merkintöihin ja määräyksiin';



CREATE TABLE regulation (
    regulation_id uuid NOT NULL,
    label text,
    content_fi text,
    content_sv text,
    decree_id integer
);



COMMENT ON TABLE regulation IS 'Kaavamääräys';



COMMENT ON COLUMN regulation.label IS 'Määräyksen yhteydessä esiintyvä kirjainlyhenne, kuten M, AP, luo, yt/kk';



COMMENT ON COLUMN regulation.content_fi IS 'Kaavamääräyksen teksti suomeksi';



COMMENT ON COLUMN regulation.content_sv IS 'Kaavamääräyksen teksti ruotsiksi';



COMMENT ON COLUMN regulation.decree_id IS 'Kaavamerkintäasetuksen mukainen numerokoodi, jos kaavamerkintä löytyy asetuksen luettelosta.';



CREATE TABLE specifier (
    object_id uuid NOT NULL,
    regulation_id uuid NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    content text NOT NULL
);



COMMENT ON TABLE specifier IS 'Mahdollinen kaavamääräyksen ilmentymäkohtainen tarkenne, esim. AP-alueen rakennuspaikkojen lukumäärä.';



COMMENT ON COLUMN specifier.object_id IS 'Viittaus kaavakohteeseen';



COMMENT ON COLUMN specifier.regulation_id IS 'Viittaus kaavamääräykseen';



COMMENT ON COLUMN specifier.priority IS 'Tarkenteiden keskinäinen järjestys. Pienemmästä suurempaan.';



COMMENT ON COLUMN specifier.content IS 'Tarkenteen sisältö';



ALTER TABLE ONLY keep_in_effect
    ADD CONSTRAINT keep_in_effect_pkey PRIMARY KEY (plan_id, target_plan_id);



ALTER TABLE ONLY object
    ADD CONSTRAINT object_pkey PRIMARY KEY (object_id);



ALTER TABLE ONLY object_regulation
    ADD CONSTRAINT object_regulation_object_id_order_key UNIQUE (object_id, priority);



ALTER TABLE ONLY object_regulation
    ADD CONSTRAINT object_regulation_pkey PRIMARY KEY (object_id, regulation_id);



ALTER TABLE ONLY plan
    ADD CONSTRAINT plan_pkey PRIMARY KEY (plan_id);



ALTER TABLE ONLY regulation
    ADD CONSTRAINT regulation_pkey PRIMARY KEY (regulation_id);



ALTER TABLE ONLY specifier
    ADD CONSTRAINT specifier_pkey PRIMARY KEY (object_id, regulation_id, priority);



CREATE INDEX object_geom_idx ON object USING gist (geom);



CREATE INDEX object_plan_id_idx ON object USING btree (plan_id);



CREATE INDEX plan_geom_idx ON plan USING gist (geom);



ALTER TABLE ONLY keep_in_effect
    ADD CONSTRAINT keep_in_effect_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES plan(plan_id);



ALTER TABLE ONLY keep_in_effect
    ADD CONSTRAINT keep_in_effect_target_plan_id_fkey FOREIGN KEY (target_plan_id) REFERENCES plan(plan_id);



ALTER TABLE ONLY object
    ADD CONSTRAINT object_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES plan(plan_id);



ALTER TABLE ONLY object_regulation
    ADD CONSTRAINT object_regulation_object_id_fkey FOREIGN KEY (object_id) REFERENCES object(object_id);



ALTER TABLE ONLY object_regulation
    ADD CONSTRAINT object_regulation_regulation_id_fkey FOREIGN KEY (regulation_id) REFERENCES regulation(regulation_id);



ALTER TABLE ONLY specifier
    ADD CONSTRAINT specifier_object_id_fkey FOREIGN KEY (object_id) REFERENCES object(object_id);



ALTER TABLE ONLY specifier
    ADD CONSTRAINT specifier_regulation_id_fkey FOREIGN KEY (regulation_id) REFERENCES regulation(regulation_id);




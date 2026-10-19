# Jasper

Helm chart for [Jasper KM](https://github.com/cjmalloy/jasper).

## Database

By default the chart runs a built in PostgreSQL StatefulSet using the official
[`postgres`](https://hub.docker.com/_/postgres) image from Docker Hub.

### PostGIS

Use the [`postgis/postgis`](https://hub.docker.com/r/postgis/postgis) image instead:

```yaml
postgresql:
  image:
    repository: postgis/postgis
    tag: "18-3.6"
```

### Configuration

PostgreSQL settings in `postgresql.config` are passed to the server as `-c key=value` arguments:

```yaml
postgresql:
  config:
    default_text_search_config: pg_catalog.english
    max_connections: 200
```

### Existing database

Disable the built in database and point Jasper at an existing one:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgres.example.com
  port: 5432
  database: jasper
  username: jasper
  # Either set the password (a secret is created for it)...
  password: ""
  # ...or reference an existing secret
  existingSecret: my-db-secret
  existingSecretPasswordKey: password
  # Optionally override host/port/database with a full JDBC URL
  jdbcUrl: ""
```

## Upgrading from 1.x

Version 2.0.0 replaces the Bitnami PostgreSQL subchart with the official `postgres` image.
Data from 1.x cannot be reused in place, so migrate it with a dump and restore:

1. Stop everything that writes to the old database, but leave the old `jasper-db` pod running.
   Keep the writers stopped until you switch over, because writes made after the dump are not migrated.
   For example, with the old release named `jasper`:
   ```sh
   helm upgrade jasper jasper/jasper --version <1.x version> --reuse-values \
     --set replicaCount=0 --set autoscaling.enabled=false \
     --set cache.enabled=false --set workload.origins=null
   ```
2. Back up the database from the old pod, and note the old `postgres` password:
   ```sh
   kubectl exec jasper-db-0 -- bash -c 'PGPASSWORD="$(cat /opt/bitnami/postgresql/secrets/postgres-password)" pg_dumpall -U postgres' > dump.sql
   kubectl exec jasper-db-0 -- cat /opt/bitnami/postgresql/secrets/postgres-password
   ```
3. Install chart 2.0.0 as a fresh install, a new release, or in a new cluster. Set the
   password to the old one, because the dump restores it with `ALTER ROLE`. Keep Jasper
   stopped so its startup migrations don't create the schema before the restore:
   ```sh
   helm install jasper jasper/jasper \
     --set postgresql.auth.postgresPassword=<old password> \
     --set replicaCount=0 --set autoscaling.enabled=false \
     --set cache.enabled=false --set workload.origins=null
   ```
4. Restore the dump into the new database (the pod is named `<fullname>-postgresql-0`):
   ```sh
   kubectl exec -i jasper-postgresql-0 -- psql -U postgres < dump.sql
   ```
   Errors that `role "postgres"` and `database "jasper"` already exist are expected and can be ignored.
5. Once the restore succeeds, start Jasper again with `helm upgrade` using your normal values
   (keep `postgresql.auth.postgresPassword` set to the old password).

### Major PostgreSQL upgrades

Future major PostgreSQL version upgrades (for example 18 to 19) use the same steps:
`pg_dumpall` from the old database, start a new database with the new image, and restore with `psql`.

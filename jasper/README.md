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
  upgrade:
    image:
      repository: postgis/postgis
      tag: "17-3.5"
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

### Upgrading from the Bitnami PostgreSQL chart

Earlier versions of this chart bundled the Bitnami PostgreSQL subchart. The built in database
uses the same names (`jasper-db` StatefulSet, Service and Secret, and the `data-jasper-db-0` PVC)
and the same StatefulSet selector, so a normal `helm upgrade` reuses the existing volume and password.

The `bitnamilegacy/postgresql` image used previously runs PostgreSQL 17. On startup the
`upgrade-dump` init container (using `postgresql.upgrade.image`, `postgres:17` by default) dumps
the existing database, and the `upgrade-restore` init container restores it into a new
PostgreSQL 18 data directory. The old data directory and the dump are kept on the volume
under `/pgdata/upgrade` and can be deleted once the upgrade has been verified. The volume needs
enough free space for the dump and a second copy of the database.

If the existing data is from a different major version, set `postgresql.upgrade.image.tag` to
match it. You can check the version with:

```sh
kubectl exec jasper-db-0 -- cat /bitnami/postgresql/data/PG_VERSION
```

If you had customized the Bitnami persistence settings (`postgresql.primary.persistence.*`),
keep the same values so the StatefulSet volume claim template is unchanged.

### Major version upgrades

The same mechanism is used for future major version upgrades: set `postgresql.upgrade.image`
to the current major version and `postgresql.image` to the new one. When the data directory
already matches `postgresql.image` the init containers do nothing, so `postgresql.upgrade.enabled`
can be left on, or set to `false` to skip them.

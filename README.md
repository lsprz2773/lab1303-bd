# 🗄️ Lab DB — PostgreSQL con Docker

Proyecto de base de datos PostgreSQL levantado con Docker Compose, incluyendo schema, datos de prueba y objetos SQL (funciones, triggers, stored procedures y vistas).

---

## 📋 Requisitos

- [Docker](https://www.docker.com/) instalado y corriendo
- [Docker Compose](https://docs.docker.com/compose/)

---

## 🚀 Levantar el proyecto

**Primera vez** (construye la imagen):
```bash
docker compose up --build -d
```

**Siguientes veces** (usa la imagen ya construida):
```bash
docker compose up -d
```

---

## 🗃️ Ejecutar los archivos SQL

Cargar el schema (tablas y estructura):
```bash
docker exec -i postgres_container psql -U postgres -d lab_db < db/actividad_b_schema.sql
```

Cargar datos y objetos SQL (funciones, triggers, SP, vistas):
```bash
docker exec -i postgres_container psql -U postgres -d lab_db < db/lab.sql
```

---

## 🧪 Probar las queries de ejemplo

Conectarse a la base de datos:
```bash
docker exec -it postgres_container psql -U postgres -d lab_db
```

Una vez dentro, copiar y pegar las queries de ejemplo que se encuentran comentadas al final de cada implementación en `db/lab.sql`.

---

## 📁 Estructura del proyecto

```
├── db/
│   ├── actividad_b_schema.sql   # Tablas y relaciones
│   └── lab.sql                  # Funciones, triggers, SP y vistas
├── docker-compose.yml
└── README.md
```
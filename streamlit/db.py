import os

import pandas as pd
import psycopg2
import streamlit as st


def _env(name, default):
    """Récupère une variable d'environnement proprement."""
    value = os.getenv(name)

    if value is None or value == "":
        return default

    return value.strip().strip('"').strip("'")


@st.cache_resource
def get_connection():
    host = _env("DB_HOST", "localhost")
    port = _env("DB_PORT", "5432")
    database = _env("DB_NAME", "marketplace")
    user = _env("DB_USER", "app")
    password = _env("DB_PASSWORD", "app12345")

    try:
        connection = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password,
            options="-c client_encoding=UTF8",
        )

        # Force l'encodage de la session PostgreSQL
        connection.set_client_encoding("UTF8")

        connection.autocommit = True
        
        return connection

    except UnicodeDecodeError:
        st.error(
            "Erreur d'encodage lors de la connexion à PostgreSQL. "
            "Vérifie notamment les paramètres DB_HOST, DB_NAME, DB_USER et DB_PASSWORD."
        )
        raise

    except psycopg2.Error as exc:
        st.error(
            f"Impossible de se connecter à PostgreSQL "
            f"({host}:{port}/{database})."
        )
        st.error(str(exc))
        raise


def load_query(query):
    connection = get_connection()

    try:
        return pd.read_sql_query(query, connection)
    finally:
        # On ne ferme pas la connexion ici car elle est gérée
        # par st.cache_resource.
        pass
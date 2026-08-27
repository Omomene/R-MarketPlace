import streamlit as st


def display_kpis(revenue, orders, average_order_value, active_sellers):
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Chiffre d'affaires", f"{revenue:,.0f} €")
    col2.metric("Commandes", f"{orders:,}")
    col3.metric("Panier moyen", f"{average_order_value:,.2f} €")
    col4.metric("Clients actifs", f"{active_sellers:,}")

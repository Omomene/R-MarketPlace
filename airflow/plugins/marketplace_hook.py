from airflow.hooks.base import BaseHook
import requests
import os


class MarketplaceAPIHook(BaseHook):

    def __init__(
        self,
        conn_id="marketplace_api",
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)

        self.conn_id = conn_id
        self.connection = self.get_connection(conn_id)

        self.base_url = os.getenv(
            "MARKETPLACE_API_URL",
            self.connection.host
        )

        self.token = os.getenv(
            "MARKETPLACE_API_TOKEN",
            self.connection.password
        )

    def _get(self, endpoint, params=None):

        headers = {
            "Authorization": f"Bearer {self.token}"
        }

        url = f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"

        self.log.info(
            f"Calling Marketplace API: {url}"
        )

        response = requests.get(
            url,
            params=params,
            headers=headers,
            timeout=30
        )

        response.raise_for_status()

        return response.json()

    def get_orders(self, date):

        return self._get(
            "orders",
            params={"date": date}
        )

    def get_sellers(self):

        return self._get("sellers")

    def get_products(self):

        return self._get("products")

    def get_customers(self):

        return self._get("customers")
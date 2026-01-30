from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Dict, List

from kubernetes import client
from nicegui import ui

HOST_RE = re.compile(r'Host\(`([^`]+)`\)')


def kube_api() -> client.CustomObjectsApi:
    """
    Create a Kubernetes API client.
    Reads SA token from disk every call to support rotation.
    """
    token = Path(os.environ["KUBE_TOKEN_FILE"]).read_text().strip()

    configuration = client.Configuration()
    configuration.host = os.environ["KUBE_API_SERVER"]
    configuration.ssl_ca_cert = os.environ["KUBE_CA_FILE"]
    configuration.api_key = {
        "authorization": f"Bearer {token}"
    }

    return client.CustomObjectsApi(
        api_client=client.ApiClient(configuration)
    )


def get_ingressroute_hosts() -> Dict[str, List[str]]:
    api = kube_api()
    results: Dict[str, List[str]] = {}

    objs = api.list_cluster_custom_object(
        group="traefik.io",
        version="v1alpha1",
        plural="ingressroutes",
    )

    for item in objs.get("items", []):
        namespace = item["metadata"]["namespace"]
        routes = item.get("spec", {}).get("routes", [])

        for route in routes:
            match = route.get("match", "")
            for host in HOST_RE.findall(match):
                results.setdefault(namespace, []).append(host)

    for ns in results:
        results[ns] = sorted(set(results[ns]))

    return dict(sorted(results.items()))

@ui.page("/")
def index() -> None:
    ui.page_title("IngressRoute Host Map")

    ui.label("Traefik IngressRoutes").classes("text-xl font-bold mb-2")

    ingresses = get_ingressroute_hosts()

    with ui.element('div').style(
        'column-width: 220px; column-gap: 0.75rem;'
    ):
        for namespace, hosts in ingresses.items():
            with ui.card().classes(
                'mb-3 break-inside-avoid p-2'
            ).style(
                'display: inline-block; width: 100%;'
            ):
                ui.label(namespace).classes("text-sm font-semibold mb-1")

                if not hosts:
                    ui.label("No Host matches").classes("text-xs text-gray-500")
                    continue

                for host in hosts:
                    ui.button(host.partition('.')[0] or host) \
                        .props(
                            f'href=https://{host} '
                            'target=_blank'
                        ) \
                        .classes("w-full mb-0.5 px-1 py-0 text-xs")

ui.run(host="0.0.0.0", port=8080, dark=True, reload=True)

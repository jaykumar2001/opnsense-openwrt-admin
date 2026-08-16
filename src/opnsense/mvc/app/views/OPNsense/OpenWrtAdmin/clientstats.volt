{{ partial("OPNsense/OpenWrtAdmin/_js_utils") }}

<style>
    .openwrt-admin-client-summary {
        margin-bottom: 12px;
        color: #6b7280;
    }

    .openwrt-admin-client-association {
        margin-bottom: 6px;
    }

    .openwrt-admin-client-association:last-child {
        margin-bottom: 0;
    }

    .openwrt-admin-client-association-meta {
        color: #6b7280;
        font-size: 12px;
    }
</style>

<script>
    $(document).ready(function() {
        var tbody = $("#openwrtAdminClientStatsRows");
        var statusLine = $("#openwrtAdminClientStatsStatus");
        var summaryLine = $("#openwrtAdminClientStatsSummary");
        var brokerBanner = "#openwrtAdminClientStatsBrokerBanner";
        var routerFilter = $("#openwrtAdminClientRouterFilter");
        var lastClients = [];

        function formatSignal(signal) {
            if (signal === null || signal === undefined || signal === "") {
                return "{{ lang._('signal n/a') }}";
            }
            return signal + " dBm";
        }

        function formatBytes(value) {
            if (value === null || value === undefined || value === "") {
                return "---";
            }

            var units = ["B", "KB", "MB", "GB", "TB"];
            var amount = Number(value);
            var unit = 0;
            while (amount >= 1024 && unit < units.length - 1) {
                amount /= 1024;
                unit += 1;
            }
            var decimals = amount >= 100 || unit === 0 ? 0 : 1;
            return amount.toFixed(decimals) + " " + units[unit];
        }

        function renderAssociations(client) {
            var wrapper = $("<div>");
            var associations = Array.isArray(client.associations) ? client.associations : [];

            if (!associations.length) {
                return $("<span>", {
                    class: "text-muted",
                    text: "n/a"
                });
            }

            associations.forEach(function(association) {
                var apLabel = association.ap_hostname || association.ap_address || "{{ lang._('Unknown AP') }}";
                var networkLabel = association.network_name || association.radio_name || "{{ lang._('unknown network') }}";
                wrapper.append(
                    $("<div>", {
                        class: "openwrt-admin-client-association"
                    }).append(
                        $("<div>").append(
                            $("<strong>").text(apLabel)
                        ).append(
                            $("<span>", {
                                text: " - " + formatSignal(association.signal_dbm)
                            })
                        )
                    ).append(
                        $("<div>", {
                            class: "openwrt-admin-client-association-meta",
                            text: networkLabel
                        })
                    ).append(
                        $("<div>", {
                            class: "openwrt-admin-client-association-meta",
                            text: "rx " + openwrtAdminFormatRate(association.rx_bps) + " / tx " + openwrtAdminFormatRate(association.tx_bps)
                        })
                    )
                );
            });

            return wrapper;
        }

        function updateRouterDropdown(clients) {
            var selected = routerFilter.val();
            var seen = {};
            var options = [{ uuid: "", label: "{{ lang._('All APs') }}" }];

            clients.forEach(function(client) {
                (client.associations || []).forEach(function(assoc) {
                    var uuid = assoc.router_uuid || "";
                    if (uuid && !seen[uuid]) {
                        seen[uuid] = true;
                        var label = assoc.ap_hostname || assoc.ap_address || uuid;
                        options.push({ uuid: uuid, label: label });
                    }
                });
            });

            options.sort(function(a, b) {
                if (a.uuid === "") return -1;
                if (b.uuid === "") return 1;
                return a.label.localeCompare(b.label);
            });

            routerFilter.empty();
            options.forEach(function(opt) {
                routerFilter.append($("<option>", { value: opt.uuid, text: opt.label }));
            });

            if (selected && routerFilter.find("option[value='" + selected + "']").length) {
                routerFilter.val(selected);
            }
        }

        function applyRouterFilter(clients) {
            var uuid = routerFilter.val();
            if (!uuid) return clients;
            return clients.filter(function(client) {
                return (client.associations || []).some(function(assoc) {
                    return assoc.router_uuid === uuid;
                });
            });
        }

        function renderRows(clients) {
            tbody.empty();
            summaryLine.text("");

            updateRouterDropdown(clients);
            var visible = applyRouterFilter(clients);

            if (!visible.length) {
                var emptyMsg = routerFilter.val()
                    ? "{{ lang._('No clients are currently associated with the selected router.') }}"
                    : "{{ lang._('No clients are currently associated with any managed AP.') }}";
                summaryLine.text(emptyMsg);
                tbody.append(
                    $("<tr>").append(
                        $("<td>", {
                            colspan: 6,
                            class: "text-center text-muted",
                            text: "{{ lang._('No Wi-Fi clients are currently connected.') }}"
                        })
                    )
                );
                return;
            }

            summaryLine.text(visible.length + (visible.length !== clients.length ? " / " + clients.length : "") + " {{ lang._('clients currently visible across the AP fleet.') }}");

            visible.forEach(function(client) {
                var hostname = client.hostname || "---";
                var ipAddress = client.ip_address || "---";
                var description = client.description_guess || "---";
                var primaryAssociation = Array.isArray(client.associations) && client.associations.length ? client.associations[0] : null;
                var throughput = primaryAssociation
                    ? "rx " + openwrtAdminFormatRate(primaryAssociation.rx_bps) + " / tx " + openwrtAdminFormatRate(primaryAssociation.tx_bps)
                    : "---";
                var totals = primaryAssociation
                    ? "rx " + formatBytes(primaryAssociation.rx_bytes) + " / tx " + formatBytes(primaryAssociation.tx_bytes)
                    : "---";

                tbody.append(
                    $("<tr>")
                        .append($("<td>").text(client.mac || ""))
                        .append($("<td>").text(hostname))
                        .append($("<td>").text(ipAddress))
                        .append($("<td>").text(description))
                        .append($("<td>").append(
                            $("<div>").text(throughput),
                            $("<div>", {class: "small text-muted", text: totals})
                        ))
                        .append($("<td>").append(renderAssociations(client)))
                );
            });
        }

        routerFilter.on("change", function() {
            renderRows(lastClients);
        });

        function refreshClientStats() {
            openwrtAdminUpdateBrokerBanner(brokerBanner);
            ajaxCall("/api/openwrtadmin/service/clients/", {}, function(data) {
                lastClients = Array.isArray(data.clients) ? data.clients : [];
                renderRows(lastClients);
                statusLine.text("{{ lang._('Updated') }} " + new Date().toLocaleTimeString());
            });
        }

        refreshClientStats();
        window.setInterval(refreshClientStats, 10000);
    });
</script>

<div class="content-box">
    <div class="row">
        <div class="col-xs-12">
            <div class="alert alert-danger hidden" id="openwrtAdminClientStatsBrokerBanner"></div>
            <div class="box box-default">
                <div class="box-header with-border">
                    <h3 class="box-title">{{ lang._('Clients') }}</h3>
                    <div class="box-tools pull-right">
                        <label for="openwrtAdminClientRouterFilter" class="control-label" style="margin-right:4px;font-weight:normal;">{{ lang._('AP Filter') }}</label>
                        <select id="openwrtAdminClientRouterFilter" class="form-control input-sm" style="display:inline-block;width:auto;margin-right:8px;">
                            <option value="">{{ lang._('All APs') }}</option>
                        </select>
                        <span class="text-muted" id="openwrtAdminClientStatsStatus"></span>
                    </div>
                </div>
                <div class="box-body">
                    <div class="openwrt-admin-client-summary" id="openwrtAdminClientStatsSummary"></div>
                    <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead>
                            <tr>
                                <th>{{ lang._('Client MAC') }}</th>
                                <th>{{ lang._('Hostname') }}</th>
                                <th>{{ lang._('IP Address') }}</th>
                                <th>{{ lang._('DHCP Description') }}</th>
                                <th>{{ lang._('Bandwidth') }}</th>
                                <th>{{ lang._('APs / Signal') }}</th>
                            </tr>
                        </thead>
                        <tbody id="openwrtAdminClientStatsRows">
                            <tr>
                                <td colspan="6" class="text-center text-muted">{{ lang._('Loading client data...') }}</td>
                            </tr>
                        </tbody>
                    </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
